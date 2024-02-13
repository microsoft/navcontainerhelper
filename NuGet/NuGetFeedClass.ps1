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

    NuGetFeed([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [string[]] $fingerprints) {
        $this.url = $nuGetServerUrl
        $this.token = $nuGetToken
        $this.patterns = $patterns
        $this.fingerprints = $fingerprints

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

    static [NuGetFeed] Create([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [string[]] $fingerprints) {
        $nuGetFeed = $script:NuGetFeedCache | Where-Object { $_.url -eq $nuGetServerUrl -and $_.token -eq $nuGetToken -and (-not (Compare-Object $_.patterns $patterns)) -and (-not (Compare-Object $_.fingerprints $fingerprints)) }
        if (!$nuGetFeed) {
            $nuGetFeed = [NuGetFeed]::new($nuGetServerUrl, $nuGetToken, $patterns, $fingerprints)
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
        if ($this.searchQueryServiceUrl -match '^https://nuget.pkg.github.com/(.*)/query$') {
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
            $queryUrl = "https://api.github.com/orgs/$organization/packages?package_type=nuget&per_page=100&page="
            $page = 1
            Write-Host -ForegroundColor Yellow "Search package using $queryUrl$page"
            $matching = @()
            while ($true) {
                $result = Invoke-RestMethod -Method GET -Headers $headers -Uri "$queryUrl$page"
                if ($result.Count -eq 0) {
                    break
                }
                $matching += @($result | Where-Object { $_.name -like "*$packageName*" -and $this.IsTrusted($_.name) } | Sort-Object { $_.id.replace('.symbols','') } | ForEach-Object { @{ "id" = $_.name; "versions" = @() } } )
                $page++
            }
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
        return $matching | ForEach-Object { Write-Host "- $($_.id)"; $_ }
    }

    [string[]] GetVersions([hashtable] $package, [bool] $descending, [bool] $allowPrerelease) {
        if (!$this.IsTrusted($package.id)) {
            throw "Package $($package.id) is not trusted on $($this.url)"
        }
        if ($package.versions.count -ne 0) {
            $versionsArr = $package.versions
        }
        else {
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
            $versionsArr = @($versions.versions)
    
        }
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
        $version = $versionStr -replace '-.+$' -as [System.Version]
        if ($nuGetVersionRange -match '^\s*([\[(]?)([\d\.]*)(,?)([\d\.]*)([\])]?)\s*$') {
            $inclFrom = $matches[1] -ne '('
            $range = $matches[3] -eq ','
            $inclTo = $matches[5] -eq ']'
            if ($matches[1] -eq '' -and $matches[5] -eq '') {
                $range = $true
            }
            if ($matches[2]) {
                $fromver = [System.Version]$matches[2]
            }
            else {
                $fromver = [System.Version]::new(0,0,0,0)
                if ($inclFrom) {
                    Write-Host "Invalid NuGet version range $nuGetVersionRange"
                    return $false
                }
            }
            if ($matches[4]) {
                $tover = [System.Version]$matches[4]
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
        $versions = $this.GetVersions($package, ($select -ne 'Earliest'), $allowPrerelease)
        if ($excludeVersions) {
            Write-Host "Exclude versions: $($excludeVersions -join ', ')"
        }
        foreach($version in $versions ) {
            if ($excludeVersions -contains $version) {
                continue
            }
            if (($select -eq 'Exact' -and [NuGetFeed]::NormalizeVersionStr($nuGetVersionRange) -eq [NuGetFeed]::NormalizeVersionStr($version)) -or ($select -ne 'Exact' -and [NuGetFeed]::IsVersionIncludedInRange($version, $nuGetVersionRange))) {
                if ($nuGetVersionRange -eq '0.0.0.0') {
                    Write-Host "$select version is $version"
                }
                else {
                    Write-Host "$select version matching '$nuGetVersionRange' is $version"
                }
                return $version
            }
        }
        return ''
    }

    [xml] DownloadNuSpec([string] $packageId, [string] $version) {
        if (!$this.IsTrusted($packageId)) {
            throw "Package $packageId is not trusted on $($this.url)"
        }
        $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant())/$($packageId.ToLowerInvariant()).nuspec"
        try {
            Write-Host "Download nuspec using $queryUrl"
            $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
            $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "$([GUID]::NewGuid().ToString()).nuspec"
            Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl -OutFile $tmpFile
            $nuspec = Get-Content -Path $tmpfile -Encoding UTF8 -Raw
            Remove-Item -Path $tmpFile -Force
            $global:ProgressPreference = $prev
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        return [xml]$nuspec
    }

    [string] DownloadPackage([string] $packageId, [string] $version) {
        if (!$this.IsTrusted($packageId)) {
            throw "Package $packageId is not trusted on $($this.url)"
        }
        $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant())/$($packageId.ToLowerInvariant()).$($version.ToLowerInvariant()).nupkg"
        $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())    
        try {
            Write-Host -ForegroundColor Green "Download package using $queryUrl"
            $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
            $filename = "$tmpFolder.zip"
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
            Expand-Archive -Path $filename -DestinationPath $tmpFolder -Force
            $global:ProgressPreference = $prev
            Remove-Item $filename -Force
            Write-Host "Package successfully downloaded"
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        return $tmpFolder
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
        $FileContent = [System.IO.File]::ReadAllBytes($package)
        $boundary = [System.Guid]::NewGuid().ToString(); 
        $LF = "`r`n";
        
        $body  = [System.Text.Encoding]::UTF8.GetBytes("--$boundary$LF")
        $body += [System.Text.Encoding]::UTF8.GetBytes("Content-Type: application/octet-stream$($LF)Content-Disposition: form-data; name=package; filename=""$([System.IO.Path]::GetFileName($package))""$($LF)$($LF)")
        $body += $fileContent
        $body += [System.Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")
        
        $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
        [System.IO.File]::WriteAllBytes($tmpFile, $body)
        Write-Host "Submitting NuGet package"
        try {
            Invoke-RestMethod -UseBasicParsing -Uri $this.packagePublishUrl -ContentType "multipart/form-data; boundary=$boundary" -Method Put -Headers $headers -inFile $tmpFile | Out-Host
            Write-Host -ForegroundColor Green "NuGet package successfully submitted"
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
