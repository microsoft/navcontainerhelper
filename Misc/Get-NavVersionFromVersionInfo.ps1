<# 
 .Synopsis
  Get NAV Version based on version info
 .Description
  Return NAV Version (like 2017, 2013r2 etc.) based on version number
 .Parameter versionInfo
  Version Info like (11.0.45332.0)
 .Example
  $mynav = "NAV $(Get-MavVersionFromVersionInfo -versionInfo $version) - build $version"
#>
function Get-NavVersionFromVersionInfo {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $versionInfo
    )

    $versionInfoArr = $versionInfo.Split(".")
    $verno = ($versionInfoArr[0]+$versionInfoArr[1])

    $versions  = @{
        "70"  = "2013"
        "71"  = "2013r2"
        "80"  = "2015"
        "90"  = "2016"
        "100" = "2017"
        "110" = "2018"
    }

    return $versions[$verno]
}
Export-ModuleMember -Function Get-NavVersionFromVersionInfo
