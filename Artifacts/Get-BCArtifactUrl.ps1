<# 
 .Synopsis
  Get a list of available artifact URLs
 .Description
  Get a list of available artifact URLs.  It can be used to create a new instance of a Container.
 .Parameter type
  OnPrem or Sandbox (default is Sandbox)
 .Parameter country
  the requested localization of Business Central
 .Parameter version
  The version of Business Central (will search for entries where the version starts with this value of the parameter)
 .Parameter select
  All or only the latest (Default Latest):
    - All: will return all possible urls in the selection.
    - Latest: will sort on version, and return latest version.
    - Daily: will return the latest build from yesterday (ignoring builds from today). Daily only works with Sandbox artifacts.
    - Weekly: will return the latest build from last week (ignoring builds from this week). Weekly only works with Sandbox artifacts.
    - Closest: will return the closest version to the version specified in version (must be a full version number).
    - SecondToLastMajor: will return the latest version where Major version number is second to Last (used to get Next Minor version from insider).
    - Current: will return the currently active sandbox release.
    - NextMajor: will return the next major sandbox release (will return empty if no Next Major is available).
    - NextMinor: will return the next minor sandbox release (will return NextMajor when the next release is a major release).
 .Parameter storageAccount
  The storageAccount that is being used where artifacts are stored (default is bcartifacts, usually should not be changed).
 .Parameter sasToken
  OBSOLETE - sasToken is no longer supported
 .Parameter accept_insiderEula
  Accept the EULA for Business Central Insider artifacts. This is required for using Business Central Insider artifacts without providing a SAS token after October 1st 2023.
 .Example
  Get the latest URL for Belgium: 
  Get-BCArtifactUrl -Type OnPrem -Select Latest -country be
  
  Get all available Artifact URLs for BC SaaS:
  Get-BCArtifactUrl -Type Sandbox -Select All
#>
function Get-BCArtifactUrl {
    [CmdletBinding()]
    param (
        [ValidateSet('OnPrem', 'Sandbox')]
        [String] $type = 'Sandbox',
        [String] $country = '',
        [String] $version = '',
        [ValidateSet('Latest', 'First', 'All', 'Closest', 'SecondToLastMajor', 'Current', 'NextMinor', 'NextMajor', 'Daily', 'Weekly')]
        [String] $select = 'Latest',
        [DateTime] $after,
        [DateTime] $before,
        [String] $storageAccount = '',
        [Obsolete("sasToken is no longer supported")]
        [String] $sasToken = '',
        [switch] $accept_insiderEula,
        [switch] $doNotCheckPlatform
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @("type","country","version","select","after","before","StorageAccount")
try {

    if ($type -eq "OnPrem") {
        if ($version -like '18.9*') {
            Write-Host -ForegroundColor Yellow 'On-premises build for 18.9 was replaced by 18.10.35134.0, using this version number instead'
            $version = '18.10.35134.0'
        }
        elseif ($version -like '17.14*') {
            Write-Host -ForegroundColor Yellow 'On-premises build for 17.14 was replaced by 17.15.35135.0, using this version number instead'
            $version = '17.15.35135.0'
        }
        elseif ($version -like '16.18*') {
            Write-Host -ForegroundColor Yellow 'On-premises build for 16.18 was replaced by 16.19.35126.0, using this version number instead'
            $version = '16.19.35126.0'
        }
        if ($select -eq "Weekly" -or $select -eq "Daily") {
            $select = 'Latest'
        }
    }

    if ($select -eq "Weekly" -or $select -eq "Daily") {
        if ($select -eq "Daily") {
            $ignoreBuildsAfter = [DateTime]::Today
        }
        else {
            $ignoreBuildsAfter = [DateTime]::Today.AddDays(-[datetime]::Today.DayOfWeek)
        }
        if ($version -ne '' -or ($after) -or ($before)) {
            throw 'You cannot specify version, before or after when selecting Daily or Weekly build'
        }
        $current = Get-BCArtifactUrl -country $country -select Latest -doNotCheckPlatform:$doNotCheckPlatform
        Write-Verbose "Current build is $current"
        if ($current) {
            $currentversion = [System.Version]($current.Split('/')[4])
            $periodic = Get-BCArtifactUrl -country $country -select Latest -doNotCheckPlatform:$doNotCheckPlatform -before ($ignoreBuildsAfter.ToUniversalTime()) -version "$($currentversion.Major).$($currentversion.Minor)"
            if (-not $periodic) {
                $periodic = Get-BCArtifactUrl -country $country -select First -doNotCheckPlatform:$doNotCheckPlatform -after ($ignoreBuildsAfter.ToUniversalTime()) -version "$($currentversion.Major).$($currentversion.Minor)"
            }
            Write-Verbose "Periodic build is $periodic"
            if ($periodic) { $current = $periodic }
        }
        $current
    }
    elseif ($select -eq "Current") {
        if ($storageAccount -ne '' -or $type -eq 'OnPrem' -or $version -ne '') {
            throw 'You cannot specify storageAccount, type=OnPrem or version when selecting Current release'
        }
        Get-BCArtifactUrl -country $country -select Latest -doNotCheckPlatform:$doNotCheckPlatform
    }
    elseif ($select -eq "NextMinor" -or $select -eq "NextMajor") {
        if ($storageAccount -ne '' -or $type -eq 'OnPrem' -or $version -ne '') {
            throw "You cannot specify storageAccount, type=OnPrem or version when selecting $select release"
        }

        $current = Get-BCArtifactUrl -country 'base' -select Latest -doNotCheckPlatform:$doNotCheckPlatform
        $currentversion = [System.Version]($current.Split('/')[4])

        $nextminorversion = "$($currentversion.Major).$($currentversion.Minor+1)."
        $nextmajorversion = "$($currentversion.Major+1).0."
        if ($currentVersion.Minor -ge 5) {
            $nextminorversion = $nextmajorversion
        }

        if (-not $country) { $country = 'w1' }
        $insiderParams = @{
            country            = $country
            storageAccount     = 'bcinsider'
            select             = 'All'
            doNotCheckPlatform = $doNotCheckPlatform
            accept_insiderEula = $accept_insiderEula
        }
        if ($before) {
            $insiderParams['before'] = $before
        }
        if ($after) {
            $insiderParams['after'] = $after
        }
        $insiders = Get-BcArtifactUrl @insiderParams
        $nextmajor = $insiders | Where-Object { $_.Split('/')[4].StartsWith($nextmajorversion) } | Select-Object -Last 1
        $nextminor = $insiders | Where-Object { $_.Split('/')[4].StartsWith($nextminorversion) } | Select-Object -Last 1

        if ($select -eq 'NextMinor') {
            $nextminor
        }
        else {
            $nextmajor
        }
    }
    else {
        if ($storageAccount -eq '') {
            $storageAccount = 'bcartifacts'
        }

        if (-not $storageAccount.Contains('.')) {
            $storageAccount += ".blob.core.windows.net"
        }
        $BaseUrl = ReplaceCDN -sourceUrl "https://$storageAccount/$($Type.ToLowerInvariant())/"
        $storageAccount = ReplaceCDN -sourceUrl $storageAccount -useBlobUrl

        if ($storageAccount -eq 'bcinsider.blob.core.windows.net' -and !$accept_insiderEULA) {
            throw "You need to accept the insider EULA (https://go.microsoft.com/fwlink/?linkid=2245051) by specifying -accept_insiderEula or by providing a SAS token to get access to insider builds"
        }

        if ($type -eq 'sandbox' -and $storageAccount -eq 'bcartifacts.blob.core.windows.net' -and $select -eq 'latest' -and $version -eq '' -and $bcContainerHelperConfig.useApproximateVersion) {
            # Temp fix / hack for Get-BcArtifact performance
            # If Microsoft changes versioning schema, this needs to change (or useApproximateVersion should be set to false)
            $now = ([DateTime]::Now).AddDays(15)
            $approximateMajor = 23+2*($now.Year-2024)+($now.Month -ge 4)+($now.Month -ge 10)
            $approximateMinor = ($now.Month + 2)%6
            $artifactUrl = Get-BCArtifactUrl -country $country -version "$approximateMajor.$approximateMinor" -select Latest -doNotCheckPlatform:$doNotCheckPlatform
            if ($artifactUrl) {
                # We found an artifact - check if it is the latest
                while ($artifactUrl) {
                    $lastGoodArtifact = $artifactUrl
                    if ($approximateMinor -eq 5) {
                        $approximateMajor += 1
                        $approximateMinor = 0
                    }
                    else {
                        $approximateMinor += 1
                    }
                    $artifactUrl = Get-BCArtifactUrl -country $country -version "$approximateMajor.$approximateMinor" -select Latest -doNotCheckPlatform:$doNotCheckPlatform
                }
                $artifactUrl = $lastGoodArtifact
            }
            else {
                # No artifact found - try previous 3 versions (else give up - maybe country is unavailable)
                $tryVersions = 3
                while (-not $artifactUrl -and $tryVersions-- -gt 0) {
                    if ($approximateMinor -eq 0) {
                        $approximateMajor -= 1
                        $approximateMinor = 5
                    }
                    else {
                        $approximateMinor -= 1
                    }
                    $artifactUrl = Get-BCArtifactUrl -country $country -version "$approximateMajor.$approximateMinor" -select Latest -doNotCheckPlatform:$doNotCheckPlatform
                }
            }
            $artifactUrl
        }
        else {
            $versionPrefix = ''
            if ($select -eq 'SecondToLastMajor') {
                if ($version) {
                    throw "You cannot specify a version when asking for the Second To Last Major version"
                }
            }
            elseif ($select -eq 'Closest') {
                if (!($version)) {
                    throw "You must specify a version number when you want to get the closest artifact Url"
                }
                $dots = ($version.ToCharArray() -eq '.').Count
                $closestToVersion = [Version]"0.0.0.0"
                if ($dots -ne 3 -or !([Version]::TryParse($version, [ref] $closestToVersion))) {
                    throw "Version number must be in the format 1.2.3.4 when you want to get the closest artifact Url"
                }
                $versionPrefix = "$($closestToVersion.Major).$($closestToVersion.Minor)."
            }
            elseif (!([string]::IsNullOrEmpty($version))) {
                $dots = ($version.ToCharArray() -eq '.').Count
                if ($dots -lt 3) {
                    # avoid 14.1 returning 14.10, 14.11 etc.
                    $version = "$($version.TrimEnd('.'))."
                }
                $versionPrefix = $Version
            }

            $parameters = @{
                "storageAccount" = $storageAccount.ToLowerInvariant()
                "Type" = $Type.ToLowerInvariant()
                "VersionPrefix" = $versionPrefix
                "Country" = $country.ToLowerInvariant()
                "doNotCheckPlatform" = $doNotCheckPlatform
            }
            if ($after) {
                $parameters["after"] = $after
            }
            if ($before) {
                $parameters["before"] = $before
            }

            $artifacts = QueryArtifactsFromIndex @parameters

            foreach($excludebuilds in $bccontainerHelperConfig.ExcludeBuilds) {
                . (Join-Path $PSScriptRoot "../NuGet/NuGetFeedClass.ps1")
                $artifacts = $artifacts | Where-Object { if ([nugetFeed]::IsVersionIncludedInRange($_.Split('/')[0], $excludebuilds)) { Write-Host "Excluding $_"; return $false } else { return $true } }
            }

            switch ($Select) {
                'All' {  
                    # Artifacts are sorted
                }
                'Latest' { 
                    $Artifacts = $Artifacts | Select-Object -Last 1
                }
                'First' { 
                    $Artifacts = $Artifacts | Select-Object -First 1
                }
                'SecondToLastMajor' { 
                    $latest = $Artifacts | Select-Object -Last 1
                    if ($latest) {
                        $latestversion = [Version]($latest.Split('/')[0])
                        $Artifacts = $Artifacts |
                            Where-Object { ([Version]($_.Split('/')[0])).Major -ne $latestversion.Major } |
                            Select-Object -Last 1
                    }
                    else {
                        $Artifacts = @()
                    }
                }
                'Closest' {
                    $closest = $Artifacts |
                        Where-Object { [Version]($_.Split('/')[0]) -ge $closestToVersion } |
                        Select-Object -First 1
                    if (-not $closest) {
                        $closest = $Artifacts | Select-Object -Last 1
                    }
                    $Artifacts = $closest           
                }
            }
    
           foreach ($Artifact in $Artifacts) {
                "$BaseUrl$($Artifact)$sasToken"
            }
        }
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Get-BCArtifactUrl
