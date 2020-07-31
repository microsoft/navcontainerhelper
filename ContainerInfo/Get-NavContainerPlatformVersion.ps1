<# 
 .Synopsis
  Get the Platform Version from a Business Central container or Business Central container image
  The function will return blank for NAV Containers
 .Description
  Returns the platform version of Business Central in the format major.minor.build.release
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the platform version
 .Example
  Get-BcContainerPlatformVersion -containerOrImageName navserver
 .Example
  Get-BcContainerPlatformVersion -containerOrImageName mcr.microsoft.com/businesscentral/onprem:dk
#>
function Get-BcContainerPlatformVersion {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -eq 0 -or $inspect.Config.Labels.maintainer -ne "Dynamics SMB") {
            throw "Container $containerOrImageName is not a NAV/BC container"
        }
        if ($inspect.Config.Labels.psobject.Properties.Name -eq 'platform') {
            return "$($inspect.Config.Labels.platform)"
        } else {
            return ""
        }
    }
}
Set-Alias -Name Get-NavContainerPlatformVersion -Value Get-BcContainerPlatformVersion
Export-ModuleMember -Function Get-BcContainerPlatformVersion -Alias Get-NavContainerPlatformVersion
