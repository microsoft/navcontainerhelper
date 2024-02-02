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
    - Weekly: will return the latest build from last week (ignoring builds from this wwek). Weekly only works with Sandbox artifacts.
    - Closest: will return the closest version to the version specified in version (must be a full version number).
    - SecondToLastMajor: will return the latest version where Major version number is second to Last (used to get Next Minor version from insider).
    - Current: will return the currently active sandbox release.
    - NextMajor: will return the next major sandbox release (will return empty if no Next Major is available).
    - NextMinor: will return the next minor sandbox release (will return NextMajor when the next release is a major release).
 .Parameter storageAccount
  The storageAccount that is being used where artifacts are stored (default is bcartifacts, usually should not be changed).
 .Parameter sasToken
  The token that for accessing protected Azure Blob Storage. Make sure to set the right storageAccount!
  Note that Business Central Insider artifacts doesn't require a sasToken after October 1st 2023, you can use the switch -accept_insiderEula to accept the EULA instead.
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
            throw 'You cannot specify version, before or after  when selecting Daily or Weekly build'
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
        $insiders = Get-BcArtifactUrl -country $country -storageAccount bcinsider -select All -sasToken $sasToken -doNotCheckPlatform:$doNotCheckPlatform -accept_insiderEula:$accept_insiderEula
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
        if ($sasToken) {
            TestSasToken -url $sasToken
        }

        if ($storageAccount -eq '') {
            $storageAccount = 'bcartifacts'
        }

        if (-not $storageAccount.Contains('.')) {
            $storageAccount += ".azureedge.net"
        }
        $BaseUrl = "https://$storageAccount/$($Type.ToLowerInvariant())/"
        $storageAccount = $storageAccount -replace ".azureedge.net", ".blob.core.windows.net"

        if ($storageAccount -eq 'bcinsider.blob.core.windows.net') {
            if (!$accept_insiderEULA) {
                if ($sasToken) {
                    Write-Host -ForegroundColor Yellow "After October 1st 2023, you can specify -accept_insiderEula to accept the insider EULA (https://go.microsoft.com/fwlink/?linkid=2245051) for Business Central Insider artifacts instead of providing a SAS token."
                }
                else {
                    throw "You need to accept the insider EULA (https://go.microsoft.com/fwlink/?linkid=2245051) by specifying -accept_insiderEula or by providing a SAS token to get access to insider builds"
                }
            }
        }

        $GetListUrl = "https://$storageAccount/$($Type.ToLowerInvariant())/"

        if ($bcContainerHelperConfig.DoNotUseCdnForArtifacts) {
            $BaseUrl = $GetListUrl
        }

        if (!([string]::IsNullOrEmpty($sasToken))) {
            $GetListUrl += $sasToken + "&comp=list&restype=container"
        }
        else {
            $GetListUrl += "?comp=list&restype=container"
        }
    
        $upMajorFilter = ''
        $upVersionFilter = ''
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
                throw "Version number must be in the format 1.2.3.4 when you want to get the closes artifact Url"
            }
            $GetListUrl += "&prefix=$($closestToVersion.Major).$($closestToVersion.Minor)."
            $upMajorFilter = "$($closestToVersion.Major)"
            $upVersionFilter = "$($closestToVersion.Minor)."
        }
        elseif (!([string]::IsNullOrEmpty($version))) {
            $dots = ($version.ToCharArray() -eq '.').Count
            if ($dots -lt 3) {
                # avoid 14.1 returning 14.10, 14.11 etc.
                $version = "$($version.TrimEnd('.'))."
            }
            $GetListUrl += "&prefix=$($Version)"
            $upMajorFilter = $version.Split('.')[0]
            $upVersionFilter = $version.Substring($version.Length).TrimStart('.')
        }

        if ($bcContainerHelperConfig.ArtifactsFeedOrganizationAndProject) {
            $feedApiUrl = "https://feeds.dev.azure.com/$($bcContainerHelperConfig.ArtifactsFeedOrganizationAndProject)/_apis/packaging/feeds/$($storageAccount.Split('.')[0])"
            $query = "&packageNameQuery=$type"
            if ($country) {
                $query += ".$country"
                if ($upMajorFilter) {
                    $query += ".$upMajorFilter"
                }
            }
            # Universal packages only supports semantic version numbers (3 digits)
            # Since Business Central artifact version numbers uses 4 digits, we name the packages: "type.country.major" and the version number is then "minor.build.revision"
            $result = invoke-restmethod -UseBasicParsing -Uri "$feedApiUrl/packages?api-version=7.0$query&includeAllVersions=$(($select -ne 'latest').ToString().ToLowerInvariant())"
            $Artifacts = @($result.value | ForEach-Object {
                # package name is type.country.major
                $null, $country, $major = $_.name.Split('.')
                if (!$upMajorFilter -or $upMajorFilter -eq $major) {
                    $_.versions | Where-Object { (!$upVersionFilter) -or ($_.version.StartsWith($upVersionFilter)) } | ForEach-Object {
                        # version number is minor.build.revision
                        return "$major.$($_.version)/$country"
                    }
                }
            })
        }
        else {
            $Artifacts = @()
            $nextMarker = ''
            $currentMarker = ''
            $downloadAttempt = 1
            $downloadRetryAttempts = 10
            do {
                if ($currentMarker -ne $nextMarker)
                {
                    $currentMarker = $nextMarker
                    $downloadAttempt = 1
                }
                Write-Verbose "Download String $GetListUrl$nextMarker"
                try
                {
                    $Response = Invoke-RestMethod -UseBasicParsing -ContentType "application/json; charset=UTF8" -Uri "$GetListUrl$nextMarker"
                    if (([int]$Response[0]) -eq 239 -and ([int]$Response[1]) -eq 187 -and ([int]$Response[2]) -eq 191) {
                        # Remove UTF8 BOM
                        $response = $response.Substring(3)
                    }
                    if (([int]$Response[0]) -eq 65279) {
                        # Remove Unicode BOM (PowerShell 7.4)
                        $response = $response.Substring(1)
                    }
                    $enumerationResults = ([xml]$Response).EnumerationResults
    
                    if ($enumerationResults.Blobs) {
                        if (($After) -or ($Before)) {
                            $artifacts += $enumerationResults.Blobs.Blob | % {
                                if ($after) {
                                    $blobModifiedDate = [DateTime]::Parse($_.Properties."Last-Modified")
                                    if ($before) {
                                        if ($blobModifiedDate -lt $before -and $blobModifiedDate -gt $after) {
                                            $_.Name
                                        }
                                    }
                                    elseif ($blobModifiedDate -gt $after) {
                                        $_.Name
                                    }
                                }
                                else {
                                    $blobModifiedDate = [DateTime]::Parse($_.Properties."Last-Modified")
                                    if ($blobModifiedDate -lt $before) {
                                        $_.Name
                                    }
                                }
                            }
                        }
                        else {
                            $artifacts += $enumerationResults.Blobs.Blob.Name
                        }
                    }
                    $nextMarker = $enumerationResults.NextMarker
                    if ($nextMarker) {
                        $nextMarker = "&marker=$nextMarker"
                    }
                }
                catch
                {
                    $downloadAttempt += 1
                    Write-Host "Error querying artifacts. Error message was $($_.Exception.Message)"
                    Write-Host
    
                    if ($downloadAttempt -le $downloadRetryAttempts)
                    {
                        Write-Host "Repeating download attempt (" $downloadAttempt.ToString() " of " $downloadRetryAttempts.ToString() ")..."
                        Write-Host
                    }
                    else
                    {
                        throw
                    }                
                }
            } while ($nextMarker)
        }

        if (!([string]::IsNullOrEmpty($country))) {
            if (-not $bcContainerHelperConfig.ArtifactsFeedOrganizationAndProject) {
                # avoid confusion between base and se
                $countryArtifacts = $Artifacts | Where-Object { $_.EndsWith("/$country", [System.StringComparison]::InvariantCultureIgnoreCase) -and ($doNotCheckPlatform -or ($Artifacts.Contains("$($_.Split('/')[0])/platform"))) }
                if (!$countryArtifacts) {
                    if (($type -eq "sandbox") -and ($bcContainerHelperConfig.mapCountryCode.PSObject.Properties.Name -eq $country)) {
                        $country = $bcContainerHelperConfig.mapCountryCode."$country"
                        $countryArtifacts = $Artifacts | Where-Object { $_.EndsWith("/$country", [System.StringComparison]::InvariantCultureIgnoreCase) -and ($doNotCheckPlatform -or ($Artifacts.Contains("$($_.Split('/')[0])/platform"))) }
                    }
                }
                $Artifacts = $countryArtifacts
            }
        }
        else {
            $Artifacts = $Artifacts | Where-Object { !($_.EndsWith("/platform", [System.StringComparison]::InvariantCultureIgnoreCase)) }
        }

        switch ($Select) {
            'All' {  
                $Artifacts = $Artifacts |
                    Sort-Object { [Version]($_.Split('/')[0]) }
            }
            'Latest' { 
                $Artifacts = $Artifacts |
                    Sort-Object { [Version]($_.Split('/')[0]) } |
                    Select-Object -Last 1
            }
            'First' { 
                $Artifacts = $Artifacts |
                    Sort-Object { [Version]($_.Split('/')[0]) } |
                    Select-Object -First 1
            }
            'SecondToLastMajor' { 
                $Artifacts = $Artifacts |
                    Sort-Object -Descending { [Version]($_.Split('/')[0]) }
                $latest = $Artifacts | Select-Object -First 1
                if ($latest) {
                    $latestversion = [Version]($latest.Split('/')[0])
                    $Artifacts = $Artifacts |
                        Where-Object { ([Version]($_.Split('/')[0])).Major -ne $latestversion.Major } |
                        Select-Object -First 1
                }
                else {
                    $Artifacts = @()
                }
            }
            'Closest' {
                $Artifacts = $Artifacts |
                    Sort-Object { [Version]($_.Split('/')[0]) }
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
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Get-BCArtifactUrl
