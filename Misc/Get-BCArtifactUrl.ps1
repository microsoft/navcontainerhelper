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
    - All: will return all possible urls in the selection
    - Latest: will sort on version, and return latest version
    - Closest: will return the closest version to the version specified in version (must be a full version number)
    - SecondToLastMajor: will return the latest version where Major version number is second to Last (used to get Next Minor version from insider)
    - Current: will return the currently active sandbox release
    - NextMajor: will return the next major sandbox release (will return empty if no Next Major is available)
    - NextMinor: will return the next minor sandbox release (will return NextMajor when the next release is a major release)
 .Parameter storageAccount
  The storageAccount that is being used where artifacts are stored (default is bcartifacts, usually should not be changed).
 .Parameter sasToken
  The token that for accessing protected Azure Blob Storage (like insider builds).  Make sure to set the right storageAccount!
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
    }

    if ($select -eq "Weekly" -or $select -eq "Daily") {
        if ($select -eq "Daily") {
            $ignoreBuildsAfter = [DateTime]::Today
        }
        else {
            $ignoreBuildsAfter = [DateTime]::Today.AddDays(-[datetime]::Today.DayOfWeek)
        }
        if ($type -eq 'OnPrem' -or $version -ne '' -or ($after) -or ($before)) {
            throw 'You cannot specify type=OnPrem, version, before or after  when selecting Daily or Weekly build'
        }
        $current = Get-BCArtifactUrl -country $country -select Latest -doNotCheckPlatform:$doNotCheckPlatform
        Write-Verbose "Current build is $current"
        if ($current) {
            $currentversion = [System.Version]($current.Split('/')[4])
            $periodic = Get-BCArtifactUrl -country $country -select Latest -doNotCheckPlatform:$doNotCheckPlatform -before ($ignoreBuildsAfter.ToUniversalTime()) -version "$($currentversion.Major).$($currentversion.Minor)"
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
        if ($sasToken -eq '') {
            throw "You need to specify an insider SasToken if you want to get $select release"
        }
        $current = Get-BCArtifactUrl -country $country -select Latest -doNotCheckPlatform:$doNotCheckPlatform
        $currentversion = [System.Version]($current.Split('/')[4])

        $nextminorversion = "$($currentversion.Major).$($currentversion.Minor+1)."
        $nextmajorversion = "$($currentversion.Major+1).0."

        $publicpreviews = Get-BcArtifactUrl -country $country -storageAccount bcpublicpreview -select All -doNotCheckPlatform:$doNotCheckPlatform
        $insiders = Get-BcArtifactUrl -country $country -storageAccount bcinsider -select All -sasToken $sasToken -doNotCheckPlatform:$doNotCheckPlatform

        $publicpreview = $publicpreviews | Where-Object { $_.Split('/')[4].StartsWith($nextmajorversion) } | Select-Object -Last 1
        $insider = $insiders | Where-Object { $_.Split('/')[4].StartsWith($nextmajorversion) } | Select-Object -Last 1
        
        $nextmajor = $insider
        if (!($insider)) {
            $nextmajor = $publicpreview
        }
        elseif ($publicpreview) {
            if ([version]($publicpreview.Split('/')[4]) -ge [version]($insider.Split('/')[4])) {
                $nextmajor = $publicpreview
            }
        }

        $insider = $insiders | Where-Object { $_.Split('/')[4].StartsWith($nextminorversion) } | Select-Object -Last 1
        $publicpreview = $publicpreviews | Where-Object { $_.Split('/')[4].StartsWith($nextminorversion) } | Select-Object -Last 1

        $nextminor = $insider
        if (!($insider)) {
            if ($publicpreview) {
                $nextminor = $publicpreview
            }
            else {
                $nextminor = $nextmajor
            }
        }
        elseif ($publicpreview) {
            if ([version]($publicpreview.Split('/')[4]) -ge [version]($insider.Split('/')[4])) {
                $nextminor = $publicpreview
            }
        }

        if ($select -eq 'NextMinor') {
            $nextminor
        }
        else {
            $nextmajor
        }
    }
    else {
        TestSasToken -sasToken $sasToken

        if ($storageAccount -eq '') {
            $storageAccount = 'bcartifacts'
        }

        if (-not $storageAccount.Contains('.')) {
            $storageAccount += ".azureedge.net"
        }
        $BaseUrl = "https://$storageAccount/$($Type.ToLowerInvariant())/"
        $storageAccount = $storageAccount -replace ".azureedge.net", ".blob.core.windows.net"

        $GetListUrl = "https://$storageAccount/$($Type.ToLowerInvariant())/"
        if (!([string]::IsNullOrEmpty($sasToken))) {
            $GetListUrl += $sasToken + "&comp=list&restype=container"
        }
        else {
            $GetListUrl += "?comp=list&restype=container"
        }
    
        if ($select -eq 'SecondToLastMajor') {
            if ($version) {
                throw "You cannot specify a version when asking for the Second To Lst Major version"
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
        }
        elseif (!([string]::IsNullOrEmpty($version))) {
            $dots = ($version.ToCharArray() -eq '.').Count
            if ($dots -lt 3) {
                # avoid 14.1 returning 14.10, 14.11 etc.
                $version = "$($version.TrimEnd('.'))."
            }
            $GetListUrl += "&prefix=$($Version)"
        }
        
        $webclient = New-Object System.Net.WebClient
        $Artifacts = @()
        $nextMarker = ""
        do {
            Write-Verbose "DownloadString $GetListUrl$nextMarker"
            $Response = $webClient.DownloadString("$GetListUrl$nextMarker")
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
        } while ($nextMarker)

        if (!([string]::IsNullOrEmpty($country))) {
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
        else {
            $Artifacts = $Artifacts | Where-Object { !($_.EndsWith("/platform", [System.StringComparison]::InvariantCultureIgnoreCase)) }
        }
    
        $Artifacts = $Artifacts | Sort-Object { [Version]($_.Split('/')[0]) }
    
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
