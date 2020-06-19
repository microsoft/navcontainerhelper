<# 
 .Synopsis
  Get a list of available artifact URLs
 .Description
  Get a list of available artifact URLs.  It can be used to create a new instance of a Container.
 .Parameter Type
  OnPrem or Sandbox
 .Parameter language
  the requested localization of Business Central
 .Parameter Version
  The version of Business Central (will search for entries where the version starts with this value of the parameter)
 .Parameter Select
  All or only the latest (Default All):
    - All: will return all possible urls in the selection
    - Latest: will sort on version, and return latest version
 .Parameter StorageAccountName
  The StorageAccount that is being used where artifacts are stored (Usually should not be changed).
  .Example
  Get the latest URL for Belgium: 
  Get-BCArtifactUrl -Type OnPrem -Select Latest -language be
  
  Get all available Artifact URLs for BC SaaS:
  Get-BCArtifactUrl -Type Sandbox -Select All
#>
function Get-BCArtifactUrl {
    [CmdletBinding()]
    param (
        [ValidateSet('OnPrem', 'Sandbox')]
        [String] $Type = 'Sandbox',
        [String] $language,
        [String] $Version,
        [ValidateSet('All', 'Latest')]
        [String] $Select = 'All',
        [String] $StorageAccountName = 'bcartifacts'
    )
    
    $BaseUrl = "https://$($StorageAccountName.ToLower()).azureedge.net/$($Type.ToLower())/?comp=list"
    
    if (!([string]::IsNullOrEmpty($version))) {
        $BaseUrl += "&prefix=$($Version)"
    }
    
    $Response = Invoke-RestMethod -Method Get -Uri $BaseUrl
    $Artifacts = ([xml] $Response.ToString().Substring($Response.IndexOf("<EnumerationResults"))).EnumerationResults.Blobs.Blob
 

    if (!([string]::IsNullOrEmpty($language))) {
        $Artifacts = $Artifacts | Where-Object { $_.Name.EndsWith($language) }
    }

    switch ($Select) {
        'All' {  
            $Artifacts = $Artifacts
        }
        'Latest' { 
            $Artifacts = $Artifacts | 
            Sort-Object { [Version]($_.name.Split('/')[0]) } | 
            Select-Object -Last 1   
        }
        Default {
            Write-Error "Unknown value for parameter 'Select'."
            return
        }
    }

    $Artifacts.Url
    
}

 
Set-Alias -Name Get-BCArtifactUrl -Value Get-NAVArtifactUrl
Export-ModuleMember -Function Get-NAVArtifactUrl -Alias Get-BCArtifactUrl
