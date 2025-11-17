#requires -Version 5.0

[NuGetFeed[]] $NuGetFeedCache = @()

# PROOF OF CONCEPT PREVIEW: This class holds the connection to a NuGet feed
class NuGetFeed {

    [string] $url
    [string] $token
    [string[]] $patterns
    [string[]] $fingerprints

    [string] $searchQueryServiceUrl
    [string] $packagePublishUrl
    [string] $packageBaseAddressUrl

    [hashtable] $orgType = @{}

    [hashtable] $searchResultsCache = @{}
    [int]       $searchResultsCacheRetentionPeriod
    [string]    $cacheFolder

    NuGetFeed([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [string[]] $fingerprints, [int] $nuGetSearchResultsCacheRetentionPeriod, [string] $nuGetCacheFolder) {
        $this.url = $nuGetServerUrl
        $this.token = $nuGetToken
        $this.patterns = $patterns
        $this.fingerprints = $fingerprints
        $this.searchResultsCacheRetentionPeriod = $nuGetSearchResultsCacheRetentionPeriod
        $this.cacheFolder = $nugetCacheFolder

        # When trusting nuget.org, you should only trust packages signed by an author or packages matching a specific pattern (like using a registered prefix or a full name)
        if ($nuGetServerUrl -like 'https://api.nuget.org/*' -and $patterns.Contains('*') -and (!$fingerprints -or $fingerprints.Contains('*'))) {
            throw "Trusting all packages on nuget.org is not supported"
        }

        try {
            $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
            $capabilities = Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $this.url
            $global:ProgressPreference = $prev
            $this.searchQueryServiceUrl = $capabilities.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' } | Select-Object -ExpandProperty '@id' | Select-Object -First 1
            if (!$this.searchQueryServiceUrl) {
                # Azure DevOps doesn't support SearchQueryService, but SearchQueryService/3.0.0-beta
                $this.searchQueryServiceUrl = $capabilities.resources | Where-Object { $_.'@type' -eq 'SearchQueryService/3.0.0-beta' } | Select-Object -ExpandProperty '@id' | Select-Object -First 1
            }
            $this.packagePublishUrl = $capabilities.resources | Where-Object { $_."@type" -eq 'PackagePublish/2.0.0' } | Select-Object -ExpandProperty '@id' | Select-Object -First 1
            $this.packageBaseAddressUrl = $capabilities.resources | Where-Object { $_."@type" -eq 'PackageBaseAddress/3.0.0' } | Select-Object -ExpandProperty '@id' | Select-Object -First 1
            if (!$this.searchQueryServiceUrl -or !$this.packagePublishUrl -or !$this.packageBaseAddressUrl) {
                Write-Host "Capabilities of NuGet server $($this.url) are not supported"
                $capabilities.resources | ForEach-Object { Write-Host "- $($_.'@type')"; Write-Host "-> $($_.'@id')" }
            }
            Write-Verbose "Capabilities of NuGet server $($this.url) are:"
            Write-Verbose "- SearchQueryService=$($this.searchQueryServiceUrl)"
            Write-Verbose "- PackagePublish=$($this.packagePublishUrl)"
            Write-Verbose "- PackageBaseAddress=$($this.packageBaseAddressUrl)"
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
    }

    static [NuGetFeed] Create([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [string[]] $fingerprints, [int] $nuGetSearchResultsCacheRetentionPeriod, [string] $nuGetCacheFolder) {
        $nuGetFeed = $script:NuGetFeedCache | Where-Object { $_.url -eq $nuGetServerUrl -and $_.token -eq $nuGetToken -and (-not (Compare-Object $_.patterns $patterns)) -and (-not (Compare-Object $_.fingerprints $fingerprints)) -and $_.searchResultsCacheRetentionPeriod -eq $nuGetSearchResultsCacheRetentionPeriod }
        if (!$nuGetFeed) {
            $nuGetFeed = [NuGetFeed]::new($nuGetServerUrl, $nuGetToken, $patterns, $fingerprints, $nuGetSearchResultsCacheRetentionPeriod, $nugetCacheFolder)
            $script:NuGetFeedCache += $nuGetFeed
        }
        return $nuGetFeed
    }

    [void] Dump([string] $message) {
        Write-Host $message
    }

    [hashtable] GetHeaders() {
        $headers = @{
            "Content-Type" = "application/json; charset=utf-8"
        }
        # nuget.org only support anonymous access
        if ($this.token -and $this.url -notlike 'https://api.nuget.org/*') {
            $headers += @{
                "Authorization" = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("user:$($this.token)")))"
            }
        }
        return $headers
    }

    [bool] IsTrusted([string] $packageId) {
        return ($packageId -and ($this.patterns | Where-Object { $packageId -like $_ }))
    }

    [hashtable[]] Search([string] $packageName) {
        $useCache = $this.searchResultsCacheRetentionPeriod -gt 0
        $hasCache = $this.searchResultsCache.ContainsKey($packageName)
        if ($hasCache) {
            if ($useCache) {
                # Clear cache older than the retention period
                $clearCache = $this.searchResultsCache[$packageName].timestamp.AddSeconds($this.searchResultsCacheRetentionPeriod) -lt (Get-Date)
            } else {
                # Clear cache if we are not using it
                $clearCache = $true
            }
            if ($clearCache) {
                $this.searchResultsCache.Remove($packageName)
                $hasCache = $false
            }
        }

        if ($useCache -and $hasCache) { 
            Write-Host "Search package using cache"
            $matching = $this.searchResultsCache[$packageName].matching
        } 
        elseif ($this.searchQueryServiceUrl -match '^https://nuget.pkg.github.com/(.*)/query$') {
            # GitHub support for SearchQueryService is unstable and is not usable
            # use GitHub API instead
            # GitHub API unfortunately doesn't support filtering, so we need to filter ourselves
            $organization = $matches[1]
            $headers = @{
                "Accept" = "application/vnd.github+json"
                "X-GitHub-Api-Version" = "2022-11-28"
            }
            if ($this.token) {
                $headers += @{
                    "Authorization" = "Bearer $($this.token)"
                }
            }
            if (-not $this.orgType.ContainsKey($organization)) {
                $orgMetadata = Invoke-RestMethod -Method GET -Headers $headers -Uri "https://api.github.com/users/$organization"
                if ($orgMetadata.type -eq 'Organization') {
                    $this.orgType[$organization] = 'orgs'
                }
                else {
                    $this.orgType[$organization] = 'users'
                }
            }
            $cacheKey = "GitHubPackages:$($this.orgType[$organization])/$organization"
            $matching = @()
            if ($this.searchResultsCacheRetentionPeriod -gt 0 -and $this.searchResultsCache.ContainsKey($cacheKey)) {
                if ($this.searchResultsCache[$cacheKey].timestamp.AddSeconds($this.searchResultsCacheRetentionPeriod) -lt (Get-Date)) {
                    Write-Host "Cache expired, removing cache $cacheKey"
                    $this.searchResultsCache.Remove($cacheKey)
                }
                else {
                    Write-Host "Search available packages using cache $cacheKey"
                    $matching = $this.searchResultsCache[$cacheKey].matching
                    Write-Host "$($matching.Count) packages found"
                }
            }
            if (-not $matching) {
                $per_page = 50
                $queryUrl = "https://api.github.com/$($this.orgType[$organization])/$organization/packages?package_type=nuget&per_page=$($per_page)&page="
                $page = 1
                $matching = @()
                while ($true) {
                    Write-Host -ForegroundColor Yellow "Search package using $queryUrl$page"
                    $result = Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri "$queryUrl$page"
                    Write-Host "$($result.Count) packages found"
                    if ($result.Count -eq 0) {
                        break
                    }
                    $matching += @($result)
                    if ($result.Count -ne $per_page) {
                        break
                    }
                    $page++
                }
                Write-Host "Total of $($matching.Count) packages found"
                $this.searchResultsCache[$cacheKey] = @{
                    matching = $matching
                    timestamp = (Get-Date)
                }
            }
            $matching = @($matching | Where-Object { $_.name -like "*$packageName*" -and $this.IsTrusted($_.name) } | Sort-Object { $_.name.replace('.symbols','') } | ForEach-Object { @{ "id" = $_.name; "versions" = @() } } )
        }
        else {
            $queryUrl = "$($this.searchQueryServiceUrl)?q=$packageName&take=50"
            try {
                Write-Host -ForegroundColor Yellow "Search package using $queryUrl"
                $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
                $searchResult = Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl
                $global:ProgressPreference = $prev
            }
            catch {
                throw (GetExtendedErrorMessage $_)
            }
            # Check that the found pattern matches the package name and the trusted patterns
            $matching = @($searchResult.data | Where-Object { $_.id -like "*$($packageName)*" -and $this.IsTrusted($_.id) } | Sort-Object { $_.id.replace('.symbols','') } | ForEach-Object { @{ "id" = $_.id; "versions" = @($_.versions.version) } } )
        }
        $exact = $matching | Where-Object { $_.id -eq $packageName -or $_.id -eq "$packageName.symbols" }
        if ($exact) {
            Write-Host "Exact match found for $packageName"
            $matching = $exact
        }
        else {
            Write-Host "$($matching.count) matching packages found"
        }

        if ($useCache -and !$hasCache) {
            # Cache the search results
            $this.searchResultsCache[$packageName] = @{
                matching = $matching
                timestamp = (Get-Date)
            }
        }

        return $matching | ForEach-Object { Write-Host "- $($_.id)"; $_ }
    }

    [string[]] GetVersions([hashtable] $package, [bool] $descending, [bool] $allowPrerelease) {
        if (!$this.IsTrusted($package.id)) {
            throw "Package $($package.id) is not trusted on $($this.url)"
        }
        if ($package.versions.count -eq 0) {
            $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($package.Id.ToLowerInvariant())/index.json"
            try {
                Write-Host -ForegroundColor Yellow "Get versions using $queryUrl"
                $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
                $versions = Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl
                $global:ProgressPreference = $prev
            }
            catch {
                throw (GetExtendedErrorMessage $_)
            }
            $package.versions = @($versions.versions)
        }
        $versionsArr = $package.versions
        Write-Host "$($versionsArr.count) versions found"
        $versionsArr = @($versionsArr | Where-Object { $allowPrerelease -or !$_.Contains('-') } | Sort-Object { ($_ -replace '-.+$') -as [System.Version]  }, { "$($_)z" } -Descending:$descending | ForEach-Object { "$_" })
        Write-Host "First version is $($versionsArr[0])"
        Write-Host "Last version is $($versionsArr[$versionsArr.Count-1])"
        return $versionsArr
    }

    # Normalize name or publisher name to be used in nuget id
    static [string] Normalize([string] $name) {
        return $name -replace '[^a-zA-Z0-9_\-]',''
    }

    static [string] NormalizeVersionStr([string] $versionStr) {
        $idx = $versionStr.IndexOf('-')
        $version = [System.version]($versionStr.Split('-')[0])
        if ($version.Build -eq -1) { $version = [System.Version]::new($version.Major, $version.Minor, 0, 0) }
        if ($version.Revision -eq -1) { $version = [System.Version]::new($version.Major, $version.Minor, $version.Build, 0) }
        if ($idx -gt 0) {
            return "$version$($versionStr.Substring($idx))"
        }
        else {
            return "$version"
        }
    }

    static [Int32] CompareVersions([string] $version1, [string] $version2) {
        $version1 = [NuGetFeed]::NormalizeVersionStr($version1)
        $version2 = [NuGetFeed]::NormalizeVersionStr($version2)
        $ver1 = $version1 -replace '-.+$' -as [System.Version]
        $ver2 = $version2 -replace '-.+$' -as [System.Version]
        if ($ver1 -eq $ver2) {
            # add a 'z' to the version to make sure that 5.1.0 is greater than 5.1.0-beta
            # Tags are sorted alphabetically (alpha, beta, rc, etc.), even though this shouldn't matter
            # New prerelease versions will always have a new version number
            return [string]::Compare("$($version1)z", "$($version2)z")
        }
        elseif ($ver1 -gt $ver2) {
            return 1
        }
        else {
            return -1
        }
    }

    # Test if version is included in NuGet version range
    # https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges
    static [bool] IsVersionIncludedInRange([string] $versionStr, [string] $nuGetVersionRange) {
        $versionStr = [NuGetFeed]::NormalizeVersionStr($versionStr)
        $version = $versionStr -replace '-.+$' -as [System.Version]
        if ($nuGetVersionRange -match '^\s*([\[(]?)([\d\.]*)(,?)([\d\.]*)([\])]?)\s*$') {
            $inclFrom = $matches[1] -ne '('
            $range = $matches[3] -eq ','
            $inclTo = $matches[5] -eq ']'
            if ($matches[1] -eq '' -and $matches[5] -eq '') {
                $range = $true
            }
            if ($matches[2]) {
                $fromver = [System.Version]([NuGetFeed]::NormalizeVersionStr($matches[2]))
            }
            else {
                $fromver = [System.Version]::new(0,0,0,0)
                if ($inclFrom) {
                    Write-Host "Invalid NuGet version range $nuGetVersionRange"
                    return $false
                }
            }
            if ($matches[4]) {
                $tover = [System.Version]([NuGetFeed]::NormalizeVersionStr($matches[4]))
            }
            elseif ($range) {
                $tover = [System.Version]::new([int32]::MaxValue,[int32]::MaxValue,[int32]::MaxValue,[int32]::MaxValue)
                if ($inclTo) {
                    Write-Host "Invalid NuGet version range $nuGetVersionRange"
                    return $false
                }
            }
            else {
                $tover = $fromver
            }
            if (!$range -and (!$inclFrom -or !$inclTo)) {
                Write-Host "Invalid NuGet version range $nuGetVersionRange"
                return $false
            }
            if ($inclFrom) {
                if ($inclTo) {
                    return $version -ge $fromver -and $version -le $tover
                }
                else {
                    return $version -ge $fromver -and $version -lt $tover
                }
            }
            else {
                if ($inclTo) {
                    return $version -gt $fromver -and $version -le $tover
                }
                else {
                    return $version -gt $fromver -and $version -lt $tover
                }
            }
        }
        return $false
    }

    [string] FindPackageVersion([hashtable] $package, [string] $nuGetVersionRange, [string[]] $excludeVersions, [string] $select, [bool] $allowPrerelease) {
        $versions = $this.GetVersions($package, !($select -eq 'Earliest' -or $select -eq 'AllAscending'), $allowPrerelease)
        if ($excludeVersions) {
            Write-Host "Exclude versions: $($excludeVersions -join ', ')"
        }
        $versionList = @()
        foreach($version in $versions ) {
            if ($excludeVersions -contains $version) {
                continue
            }
            if (($select -eq 'Exact' -and [NuGetFeed]::NormalizeVersionStr($nuGetVersionRange) -eq [NuGetFeed]::NormalizeVersionStr($version)) -or ($select -ne 'Exact' -and [NuGetFeed]::IsVersionIncludedInRange($version, $nuGetVersionRange))) {
                if ($select -eq 'AllAscending' -or $select -eq 'AllDescending') {
                    Write-Host "Include $version"
                }
                elseif ($nuGetVersionRange -eq '0.0.0.0') {
                    Write-Host "$select version is $version"
                }
                else {
                    Write-Host "$select version matching '$nuGetVersionRange' is $version"
                }
                $versionList += @($version)
            }
        }
        return ($versionList -join ',')
    }

    # Download the specs for the package with id = packageId and version = version
    # The following properties are returned:
    # - id: the package id
    # - name: the package name (either title, description or id from the nuspec)
    # - version: the package version
    # - authors: the package authors
    # - dependencies: the package dependencies (id and version range)
    [PSCustomObject] DownloadPackageSpec([string] $packageId, [string] $version) {
        $nuSpecName = "$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant()).json"
        $nuSpecFileName = Join-Path $this.cacheFolder $nuSpecName
        $nuSpecMutex = New-Object System.Threading.Mutex($false, $nuSpecName.Replace('/','_').Replace('\','_'))
        try {
            try {
                if (!$nuSpecMutex.WaitOne(1000)) {
                    Write-Host "Waiting for other process downloading nuspec '$($nuSpecName)'"
                    $nuSpecMutex.WaitOne() | Out-Null
                    Write-Host "Other process completed download"
                }
            }
            catch [System.Threading.AbandonedMutexException] {
               Write-Host "Other process terminated abnormally"
            }
            if (Test-Path $nuSpecFileName) {
                Write-Host "Using cached nuspec for $packageId version $version"
                (Get-Item $nuSpecFileName).LastWriteTime = Get-Date
                return (Get-Content -Path $nuSpecFileName | ConvertFrom-Json | ConvertTo-HashTable)
            }
            if (!$this.IsTrusted($packageId)) {
                throw "Package $packageId is not trusted on $($this.url)"
            }
            if ($this.packageBaseAddressUrl -like 'https://nuget.pkg.github.com/*') {
                $queryUrl = "$($this.packageBaseAddressUrl.SubString(0,$this.packageBaseAddressUrl.LastIndexOf('/')))/$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant()).json"
                Write-Host "Download nuspec using $queryUrl"
                $response = Invoke-WebRequest -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl
                $content = $response.Content | ConvertFrom-Json
                if (!($content.PSObject.Properties.Name -eq 'catalogEntry') -or ($null -eq $content.catalogEntry)) {
                    throw "Package $packageId version $version not found on"
                }
                $returnValue = @{
                    "id" = $content.catalogEntry.id
                    "name" = $content.catalogEntry.description
                    "version" = $content.catalogEntry.version
                    "authors" = $content.catalogEntry.authors
                    "dependencies" = $content.catalogEntry.dependencyGroups | ForEach-Object { $_.dependencies | ForEach-Object { @{"id" = $_.id; "version" = $_.range.replace(' ','') } } }
                }
            }
            else {
                $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant())/$($packageId.ToLowerInvariant()).nuspec"
                try {
                    Write-Host "Download nuspec using $queryUrl"
                    $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
                    $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "$([GUID]::NewGuid().ToString()).nuspec"
                    Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl -OutFile $tmpFile
                    $nuspec = [xml](Get-Content -Path $tmpfile -Encoding UTF8 -Raw)
                    Remove-Item -Path $tmpFile -Force
                    $global:ProgressPreference = $prev
                }
                catch {
                    throw (GetExtendedErrorMessage $_)
                }
                if ($nuspec.package.metadata.PSObject.Properties.Name -eq 'title') {
                    $appName = $nuspec.package.metadata.title
                }
                elseif ($nuspec.package.metadata.PSObject.Properties.Name -eq 'description') {
                    $appName = $nuspec.package.metadata.description
                }
                else {
                    $appName = $nuspec.package.metadata.id
                }
                if ($nuspec.package.metadata.PSObject.Properties.Name -eq 'Dependencies') {
                    $dependencies = @($nuspec.package.metadata.Dependencies.GetEnumerator() | ForEach-Object { @{"id" = $_.id; "version" = $_.version } })
                }
                else {
                    $dependencies = @()
                }
                $returnValue = @{
                    "id" = $nuspec.package.metadata.id
                    "name" = $appName
                    "version" = $nuspec.package.metadata.version
                    "authors" = $nuspec.package.metadata.authors
                    "dependencies" = $dependencies
                }
            }
            New-Item -Path $nuSpecFileName -ItemType File -Force -Value ($returnValue | ConvertTo-Json -Depth 99) | Out-Null
            return $returnValue
        }
        finally {
            $nuSpecMutex.ReleaseMutex()
        }
    }

    [string] DownloadPackage([string] $packageId, [string] $version) {
        $packageSubFolder = "$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant())"
        $packageMutex = New-Object System.Threading.Mutex($false, $packageSubFolder.Replace('/','_').Replace('\','_'))
        try {
            try {
                if (!$packageMutex.WaitOne(1000)) {
                    Write-Host "Waiting for other process downloading package '$($packageSubFolder)'"
                    $packageMutex.WaitOne() | Out-Null
                    Write-Host "Other process completed download"
                }
            }
            catch [System.Threading.AbandonedMutexException] {
               Write-Host "Other process terminated abnormally"
            }

            if (!$this.IsTrusted($packageId)) {
                throw "Package $packageId is not trusted on $($this.url)"
            }
            $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant())/$($packageId.ToLowerInvariant()).$($version.ToLowerInvariant()).nupkg"
            $packageCacheFolder = Join-Path $this.cacheFolder $packageSubFolder
            if (test-Path $packageCacheFolder) {
                Write-Host "Using cached package for $packageId version $version"
                (Get-Item $packageCacheFolder).LastWriteTime = Get-Date
            }
            else {
                try {
                    Write-Host -ForegroundColor Green "Download package using $queryUrl"
                    $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
                    $filename = "$($packageCacheFolder).zip"
                    New-Item -Path $packageCacheFolder -ItemType Container | Out-Null
                    Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl -OutFile $filename
                    if ($this.fingerprints) {
                        $arguments = @("nuget", "verify", $filename)
                        if ($this.fingerprints.Count -eq 1 -and $this.fingerprints[0] -eq '*') {
                            Write-Host "Verifying package using any certificate"
                        }
                        else {
                            Write-Host "Verifying package using $($this.fingerprints -join ', ')"
                            $arguments += @("--certificate-fingerprint $($this.fingerprints -join ' --certificate-fingerprint ')")
                        }
                        cmddo -command 'dotnet' -arguments $arguments -silent -messageIfCmdNotFound "dotnet not found. Please install it from https://dotnet.microsoft.com/download"
                    }
                    Expand-Archive -Path $filename -DestinationPath $packageCacheFolder -Force
                    $global:ProgressPreference = $prev
                    Write-Host "Package successfully downloaded"
                }
                catch {
                    if (Test-Path $packageCacheFolder) {
                        Remove-Item $packageCacheFolder -Recurse -Force
                    }
                    throw (GetExtendedErrorMessage $_)
                }
                finally {
                    if (Test-Path $filename) {
                        Remove-Item $filename -Force
                    }
                }
            }
            $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
            New-Item -Path $tmpFolder -ItemType Container | Out-Null
            Copy-Item -Path (Join-Path $packageCacheFolder '*') -Destination $tmpFolder -Recurse -Force
            return $tmpFolder
        }
        finally {
            $packageMutex.ReleaseMutex()
        }
    }

    [void] PushPackage([string] $package) {
        if (!($this.token)) {
            throw "NuGet token is required to push packages"
        }
        Write-Host "Preparing NuGet Package for submission"
        $headers = $this.GetHeaders()
        $headers += @{
            "X-NuGet-ApiKey" = $this.token
            "X-NuGet-Client-Version" = "6.3.0"
        }
        $boundary = [System.Guid]::NewGuid().ToString();
        $LF = "`r`n";
        $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
        $fs = [System.IO.File]::OpenWrite($tmpFile)
        $fs | Add-Member -MemberType ScriptMethod -Name WriteBytes -Value { param($bytes) $this.Write($bytes, 0, $bytes.Length) }
        try {
            $fs.WriteBytes([System.Text.Encoding]::UTF8.GetBytes("--$boundary$LF"))
            $fs.WriteBytes([System.Text.Encoding]::UTF8.GetBytes("Content-Type: application/octet-stream$($LF)Content-Disposition: form-data; name=package; filename=""$([System.IO.Path]::GetFileName($package))""$($LF)$($LF)"))
            $fs.WriteBytes([System.IO.File]::ReadAllBytes($package))
            $fs.WriteBytes([System.Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF"))
        } finally {
            $fs.Close()
        }
        
        Write-Host "Submitting NuGet package"
        try {
            Invoke-RestMethod -UseBasicParsing -Uri $this.packagePublishUrl -ContentType "multipart/form-data; boundary=$boundary" -Method Put -Headers $headers -inFile $tmpFile | Out-Host
            Write-Host -ForegroundColor Green "NuGet package successfully submitted"

            # Clear matching search results caches
            @( $this.searchResultsCache.Keys ) | 
                Where-Object { $package -like "*$($_)*" -or $_ -like 'GitHubPackages:*' } | 
                ForEach-Object { $this.searchResultsCache.Remove($_) }
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Status -eq "ProtocolError" -and $_.Exception.Response -is [System.Net.HttpWebResponse]) {
                $response = [System.Net.HttpWebResponse]($_.Exception.Response)
                if ($response.StatusCode -eq [System.Net.HttpStatusCode]::Conflict) {
                    Write-Host -ForegroundColor Yellow "NuGet package already exists"
                }
                else {
                    throw (GetExtendedErrorMessage $_)
                }
            }
            else {
                throw (GetExtendedErrorMessage $_)
            }
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        finally {
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        }
    
    }
}
