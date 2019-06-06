<# 
 .Synopsis
  Get the Platform Version from a BC Container or BC Container image
  The function will return blank for NAV Containers
 .Description
  Returns the platform version of Business Central in the format major.minor.build.release
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the platform version
 .Example
  Get-NavContainerPlatformVersion -containerOrImageName navserver
 .Example
  Get-NavContainerPlatformVersion -containerOrImageName mcr.microsoft.com/businesscentral/onprem:dk
#>
function Get-NavContainerPlatformVersion {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -eq 0) {
            throw "Container $containerOrImageName is not a NAV/BC container"
        }
        if ($inspect.Config.Labels.psobject.Properties.Match('platform').Count -eq 0) {
            return ""
        } else {
            return "$($inspect.Config.Labels.platform)"
        }
    }
}
Set-Alias -Name Get-BCContainerPlatformVersion -Value Get-NavContainerPlatformVersion
Export-ModuleMember -Function Get-NavContainerPlatformVersion -Alias Get-BCContainerPlatformVersion
