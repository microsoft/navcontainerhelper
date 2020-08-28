<# 
 .Synopsis
  Get a list of available artifact URLs
 .Description
  Get a list of available artifact URLs.  It can be used to create a new instance of a Container.
 .Parameter type
  OnPrem or Sandbox
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
 .Parameter storageAccount
  The storageAccount that is being used where artifacts are stored (Usually should not be changed).
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
        [String] $country,
        [String] $version,
        [ValidateSet('Latest', 'All', 'Closest', 'SecondToLastMajor')]
        [String] $select = 'Latest',
        [String] $storageAccount = 'bcartifacts',
        [String] $sasToken,
        [switch] $doNotCheckPlatform
    )
    
    TestSasToken -sasToken $sasToken

    do {
        $retry = $false
        try {
            if (-not $storageAccount.Contains('.')) {
                $storageAccount += ".azureedge.net"
            }
            $BaseUrl = "https://$storageAccount/$($Type.ToLower())/"
            
            $GetListUrl = $BaseUrl
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
        
            $Artifacts = @()
            $nextMarker = ""
            do {
                Write-verbose "Invoke-RestMethod -Method Get -Uri $GetListUrl$nextMarker"
                $Response = Invoke-RestMethod -Method Get -Uri "$GetListUrl$nextMarker"
                $enumerationResults = ([xml] $Response.ToString().Substring($Response.IndexOf("<EnumerationResults"))).EnumerationResults
                if ($enumerationResults.Blobs) {
                    $Artifacts += $enumerationResults.Blobs.Blob.Name
                }
                $nextMarker = $enumerationResults.NextMarker
                if ($nextMarker) {
                    $nextMarker = "&marker=$nextMarker"
                }
            } while ($nextMarker)
        
            if (!([string]::IsNullOrEmpty($country))) {
                # avoid confusion between base and se
                $Artifacts = $Artifacts | Where-Object { $_.EndsWith("/$country") -and ($doNotCheckPlatform -or ($Artifacts.Contains("$($_.Split('/')[0])/platform"))) }
            }
            else {
                $Artifacts = $Artifacts | Where-Object { !($_.EndsWith("/platform")) }
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
        }
        catch {
            if ($storageAccount -notlike "*.azureedge.net") {
                throw
            }
            $storageAccount = $storageAccount -replace ".azureedge.net", ".blob.core.windows.net"
            $retry = $true
        }
    } while ($retry)

    foreach ($Artifact in $Artifacts) {
        "$BaseUrl$($Artifact)$sasToken"
    }
}
Export-ModuleMember -Function Get-BCArtifactUrl
