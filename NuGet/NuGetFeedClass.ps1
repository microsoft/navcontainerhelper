#requires -Version 5.0

# This class holds the connection to a NuGet feed
class NuGetFeed {

    [string] $url
    [string] $token
    [string[]] $patterns
    [bool] $silent = $false

    [string] $searchQueryServiceUrl
    [string] $packagePublishUrl
    [string] $packageBaseAddressUrl

    NuGetFeed([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [bool] $silent) {
        $this.url = $nuGetServerUrl
        $this.token = $nuGetToken
        $this.patterns = $patterns
        $this.silent = $silent

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
                $capabilities.resources | ForEach-Object { $this.Dump("- $($_.'@type')"); $this.Dump("-> $($_.'@id')") }
            }
            $this.Dump("$($nuGetServerUrl)::SearchQueryService=$($this.searchQueryServiceUrl)")
            $this.Dump("$($nuGetServerUrl)::PackagePublish=$($this.packagePublishUrl)")
            $this.Dump("$($nuGetServerUrl)::PackageBaseAddress=$($this.packageBaseAddressUrl)")
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
    }

    static [NuGetFeed] Create([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns, [bool] $silent) {
        return [NuGetFeed]::new($nuGetServerUrl, $nuGetToken, $patterns, $silent)
    }

    static [NuGetFeed] Create([string] $nuGetServerUrl, [string] $nuGetToken, [string[]] $patterns) {
        return [NuGetFeed]::new($nuGetServerUrl, $nuGetToken, $patterns, $false)
    }

    [void] Dump([string] $message) {
        if (!$this.silent) {
            Write-Host $message
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

    [string[]] GetVersions([string] $packageId) {
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
        $versionsArr = @($versions.versions | ForEach-Object { [System.Version]$_ } | Sort-Object -Descending | ForEach-Object { "$_" })
        $this.Dump("Latest version is $($versionsArr[0])")
        return $versionsArr
    }

    # Normalize name or publisher name to be used in nuget id
    static [string] Normalize([string] $name) {
        return $name -replace '[^a-zA-Z0-9_\-]',''
    }

    # Test if version is included in NuGet version range
    # https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges
    static [bool] IsVersionIncludedInRange([System.Version] $version, [string] $nuGetVersionRange) {
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

    [string] FindPackageVersion([string] $packageId, [string] $nuGetVersionRange) {
        foreach($version in $this.GetVersions($packageId)) {
            if ([NuGetFeed]::IsVersionIncludedInRange($version, $nuGetVersionRange)) {
                $this.Dump("Latest version matching $nuGetVersionRange is $version")
                return $version
            }
        }
        return ''
    }

    [string] DownloadPackage([string] $packageId) {
        $version = $this.GetVersions($packageId)[0]
        return $this.DownloadPackage($packageId, $version)
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


#function CopyFileToStream([string] $filename, [System.IO.Stream] $stream) {
#    $bytes = [System.IO.File]::ReadAllBytes($filename)
#    $stream.Write($bytes,0,$bytes.Length)
#}
#
#$nuspecpart = [System.IO.Packaging.PackUriHelper]::CreatePartUri([Uri]::new("manifest.nuspec",[System.UriKind]::Relative))
#$apppart = [System.IO.Packaging.PackUriHelper]::CreatePartUri([Uri]::new("Microsoft_Tests-Resource.app",[System.UriKind]::Relative))
#
#$package = [System.IO.Packaging.Package]::Open("C:\Users\freddyk\Downloads\test\package.zip", [System.IO.FileMode]::Create)
#
#$part1 = $package.CreatePart($nuspecpart, 'text/xml')
#CopyFileToStream -filename "C:\Users\freddyk\Downloads\test\manifest.nuspec" -stream ($part1.GetStream())
#
#$part2 = $package.CreatePart($apppart, 'application/octet-stream')
#CopyFileToStream -filename "C:\Users\freddyk\Downloads\test\Microsoft_Tests-Resource.app" -stream ($part2.GetStream())
#
#$package.Close()
#

#$gitHubFeed = [NuGetFeed]::new("https://nuget.pkg.github.com/businesscentralapps/index.json", (gh auth token))
#$packageId = $gitHubFeed.Search('appsource-55456f47-e1bc-4ed6-98a0-8336de116d00')
#$versions = $gitHubFeed.GetVersions($packageId)
#$gitHubFeed.DownloadPackage($packageId, $versions[0])
#$packageId = $gitHubFeed.Search('appsource-c75a45c6-4e83-46e1-b17b-48c6506c19f3')
#$gitHubFeed.DownloadPackage($packageId)
#
#$nuGetFeed = [NuGetFeed]::new("https://api.nuget.org/v3/index.json", "")
#$packageId = $nuGetFeed.Search('142d5fd8-ecb6-46d5-b417-a14b1b1594f0')
#$versions = $nuGetFeed.GetVersions($packageId)
#$nuGetFeed.DownloadPackage($packageId, $versions[0])
#
#$devOpsFeed = [NuGetFeed]::new('https://pkgs.dev.azure.com/freddydk/apps/_packaging/BCapps3/nuget/v3/index.json','')
#$packageId = $devOpsFeed.Search('437dbf0e-84ff-417a-965d-ed2bb9650972')
#$versions = $devOpsFeed.GetVersions($packageId)
#$devOpsFeed.DownloadPackage($packageId, $versions[0])
#