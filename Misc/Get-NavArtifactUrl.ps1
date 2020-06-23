<# 
 .Synopsis
  Get a list of available artifact URLs
 .Description
  Get a list of available artifact URLs.  It can be used to create a new instance of a Container.
 .Parameter nav
  The requested version of NAV (2016,2017,2018)
 .Parameter cu
  The requested Cumulative update 
 .Parameter country
  the requested localization of Business Central
 .Parameter select
  All or only the latest (Default Latest):
    - All: will return all possible urls in the selection
    - Latest: will sort on version, and return latest version
 .Example
  Get NAV 2017 CU30 URL for Belgium: 
  Get-NavArtifactUrl -Nav 2017 -cu cu30 -Select Latest -language be
 
  Get all available Artifact URLs for NAV 2018:
  Get-NAVArtifactUrl -Select All
#>
function Get-NavArtifactUrl {
    [CmdletBinding()]
    param (
        [ValidateSet('2016','2017','2018')]
        [String] $nav = '2018',
        [String] $cu,
        [String] $country,
        [ValidateSet('All', 'Latest')]
        [String] $select = 'Latest'
    )
    
    $version = (@{ "2016" = "9.0"; "2017" = "10.0"; "2018" = "11.0" })[$nav]

    if ($cu) {
        $w1artifactUrls = Get-BCArtifactUrl -type OnPrem -country w1 -version $version -select All
        if ($cu -eq "rtm") {
            $idx = 0
        }
        else {
            $idx = [int]::Parse($cu.TrimStart('cu'))
        }
        $version = $w1artifactUrls[$idx].Substring($w1artifactUrls[$idx].IndexOf('/onprem/')).Split('/')[2]
        Get-BCArtifactUrl -type OnPrem -country $country -version $version -select $select
    }
    else {
        Get-BCArtifactUrl -type OnPrem -country $country -version $version -select $select
    }
}
Export-ModuleMember -Function Get-NAVArtifactUrl
