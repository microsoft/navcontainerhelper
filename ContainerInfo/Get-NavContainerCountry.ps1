<# 
 .Synopsis
  Get the country version from a NAV/BC Ccontainer or a NAV/BC Container image
 .Description
  Returns the country version (localization) for the version of NAV or Business Central in the Container or ContainerImage
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the country version
 .Example
  Get-BcContainerCountry -containerOrImageName navserver
 .Example
  Get-BcContainerCountry -containerOrImageName mcr.microsoft.com/businesscentral/onprem:dk
#>
function Get-BcContainerCountry {
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
        return "$($inspect.Config.Labels.country)"
    }
}
Set-Alias -Name Get-NavContainerCountry -Value Get-BcContainerCountry
Export-ModuleMember -Function Get-BcContainerCountry -Alias Get-NavContainerCountry
