<# 
 .Synopsis
  Get the generic tag for a Nav container or a Nav container image
 .Description
  Returns the generic Tag version referring to a release from http://www.github.com/microsoft/nav-docker
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the generic tag
 .Example
  Get-NavContainerGenericTag -containerOrImageName navserver
 .Example
  Get-NavContainerGenericTag -containerOrImageName navdocker.azurecr.io/dynamics-nav:2017
#>
function Get-NavContainerGenericTag {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        return "$($inspect.Config.Labels.tag)"
    }
}
Export-ModuleMember -function Get-NavContainerGenericTag
