#requires -Version 5.0

[NuGetFeed[]] $NuGetFeedCache = @()

# PROOF OF CONCEPT PREVIEW: This class holds the connection to a NuGet feed
class NuGetFeed {

    [string] $url
    [string] $token
    [string[]] $patterns
    [bool] $verbose = $false

    [string] $searchQueryServiceUrl
    [string] $packagePublishUrl
    [string] $packageBaseAddressUrl

    NuGetFeed([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [bool] $verbose) {
        $this.url = $nuGetServerUrl
        $this.token = $nuGetToken
        $this.patterns = $patterns
        $this.verbose = $verbose

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
                $this.Dump("Capabilities of NuGet server $($this.url) are not supported")
                $capabilities.resources | ForEach-Object { $this.Dump("- $($_.'@type')"); $this.Dump("-> $($_.'@id')") }
            }
            $this.Dump("Capabilities of NuGet server $($this.url) are:")
            $this.Dump("- SearchQueryService=$($this.searchQueryServiceUrl)")
            $this.Dump("- PackagePublish=$($this.packagePublishUrl)")
            $this.Dump("- PackageBaseAddress=$($this.packageBaseAddressUrl)")
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
    }

    static [NuGetFeed] Create([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [bool] $verbose) {
        $nuGetFeed = $script:NuGetFeedCache | Where-Object { $_.url -eq $nuGetServerUrl -and $_.token -eq $nuGetToken -and $_.patterns -eq $patterns -and $_.verbose -eq $verbose }
        if (!$nuGetFeed) {
            $nuGetFeed = [NuGetFeed]::new($nuGetServerUrl, $nuGetToken, $patterns, $verbose)
            $script:NuGetFeedCache += $nuGetFeed
        }
        return $nuGetFeed
    }

    static [NuGetFeed] Create([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns) {
        return [NuGetFeed]::Create($nuGetServerUrl, $nuGetToken, $patterns, $false)
    }

    [void] Dump([string] $message) {
        if ($message -like '::*' -and $this.verbose) {
            Write-Host $message
        }
        else {
            Write-Verbose $message
        }
    }

    [hashtable] GetHeaders() {
        $headers = @{
            "Content-Type" = "application/json; charset=utf-8"
        }
        if ($this.token) {
            $headers += @{
                "Authorization" = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("user:$($this.token)")))"
            }
        }
        return $headers
    }

    [bool] IsTrusted([string] $packageId) {
        return ($packageId -and ($this.patterns | Where-Object { $packageId -like $_ }))
    }

    [string[]] Search([string] $packageName) {
        $queryUrl = "$($this.searchQueryServiceUrl)?q=$packageName"
        try {
            $this.Dump("Search package using $queryUrl")
            $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
            $searchResult = Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl
            $global:ProgressPreference = $prev
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        # Check that the found pattern matches the package name and the trusted patterns
        $matching = @($searchResult.data | Where-Object { $_.id -like "*$($packageName)*" -and $this.IsTrusted($_.id) })
        $this.Dump("$($matching.count) matching packages found")
        return $matching | ForEach-Object { $this.Dump("- $($_.id)"); $_.id }
    }

    [string[]] GetVersions([string] $packageId, [bool] $descending, [bool] $allowPrerelease) {
        if (!$this.IsTrusted($packageId)) {
            throw "Package $packageId is not trusted on $($this.url)"
        }
        $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($packageId.ToLowerInvariant())/index.json"
        try {
            $this.Dump("Get versions using $queryUrl")
            $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
            $versions = Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl
            $global:ProgressPreference = $prev
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        $this.Dump("$($versions.versions.count) versions found")
        $versionsArr = @($versions.versions | Where-Object { $allowPrerelease -or !$_.Contains('-') } | Sort-Object { ($_ -replace '-.+$') -as [System.Version]  }, { "$($_)z" } -Descending:$descending | ForEach-Object { "$_" })
        $this.Dump("First version is $($versionsArr[0])")
        $this.Dump("Last version is $($versionsArr[$versionsArr.Count-1])")
        return $versionsArr
    }

    # Normalize name or publisher name to be used in nuget id
    static [string] Normalize([string] $name) {
        return $name -replace '[^a-zA-Z0-9_\-]',''
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
                    throw "Invalid NuGet version range $nuGetVersionRange"
                }
            }
            if ($matches[4]) {
                $tover = [System.Version]$matches[4]
            }
            elseif ($range) {
                $tover = [System.Version]::new([int32]::MaxValue,[int32]::MaxValue,[int32]::MaxValue,[int32]::MaxValue)
                if ($inclTo) {
                    throw "Invalid NuGet version range $nuGetVersionRange"
                }
            }
            else {
                $tover = $fromver
            }
            if (!$range -and (!$inclFrom -or !$inclTo)) {
                throw "Invalid NuGet version range $nuGetVersionRange"
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

    [string] FindPackageVersion([string] $packageId, [string] $nuGetVersionRange, [string[]] $excludeVersions, [string] $select, [bool] $allowPrerelease) {
        foreach($version in $this.GetVersions($packageId, ($select -ne 'Earliest'), $allowPrerelease)) {
            if ($excludeVersions -contains $version) {
                continue
            }
            if (($select -eq 'Exact' -and $nuGetVersionRange -eq $version) -or ($select -ne 'Exact' -and [NuGetFeed]::IsVersionIncludedInRange($version, $nuGetVersionRange))) {
                $this.Dump("$select version matching $nuGetVersionRange is $version")
                return $version
            }
        }
        return ''
    }

    [string] DownloadPackage([string] $packageId) {
        $version = $this.GetVersions($packageId,$true,$false)[0]
        return $this.DownloadPackage($packageId, $version)
    }

    [xml] DownloadNuSpec([string] $packageId, [string] $version) {
        if (!$this.IsTrusted($packageId)) {
            throw "Package $packageId is not trusted on $($this.url)"
        }
        $queryUrl = "$($this.packageBaseAddressUrl.TrimEnd('/'))/$($packageId.ToLowerInvariant())/$($version.ToLowerInvariant())/$($packageId.ToLowerInvariant()).nuspec"
        try {
            $this.Dump("Download nuspec using $queryUrl")
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
            $this.Dump("Download package using $queryUrl")
            $prev = $global:ProgressPreference; $global:ProgressPreference = "SilentlyContinue"
            Invoke-RestMethod -UseBasicParsing -Method GET -Headers ($this.GetHeaders()) -Uri $queryUrl -OutFile "$tmpFolder.zip"
            Expand-Archive -Path "$tmpFolder.zip" -DestinationPath $tmpFolder -Force
            $global:ProgressPreference = $prev
            Remove-Item "$tmpFolder.zip"
            $this.Dump("Package successfully downloaded")
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
