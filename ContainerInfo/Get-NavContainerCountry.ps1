<# 
 .Synopsis
  Get the country version from a NAV/BC Ccontainer or a NAV/BC Container image
 .Description
  Returns the country version (localization) for the version of NAV or Business Central in the Container or ContainerImage
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the country version
 .Example
  Get-NavContainerCountry -containerOrImageName navserver
 .Example
  Get-NavContainerCountry -containerOrImageName mcr.microsoft.com/businesscentral/onprem:dk
#>
function Get-NavContainerCountry {
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
        return "$($inspect.Config.Labels.country)"
    }
}
Set-Alias -Name Get-BCContainerCountry -Value Get-NavContainerCountry
Export-ModuleMember -Function Get-NavContainerCountry -Alias Get-BCContainerCountry
