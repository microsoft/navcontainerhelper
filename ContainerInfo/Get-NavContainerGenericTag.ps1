<# 
 .Synopsis
  Get the generic tag for a NAV/BC Container or a NAV/BC Container image
 .Description
  Returns the generic Tag version referring to a release from http://www.github.com/microsoft/nav-docker
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the generic tag
 .Example
  Get-NavContainerGenericTag -containerOrImageName navserver
 .Example
  Get-NavContainerGenericTag -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-NavContainerGenericTag {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('tag').Count -eq 0) {
            throw "Container $containerOrImageName is not a NAV/BC container"
        }
        return "$($inspect.Config.Labels.tag)"
    }
}
Set-Alias -Name Get-BCContainerGenericTag -Value Get-NavContainerGenericTag
Export-ModuleMember -Function Get-NavContainerGenericTag -Alias Get-BCContainerGenericTag
