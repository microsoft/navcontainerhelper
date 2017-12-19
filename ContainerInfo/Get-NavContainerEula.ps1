<# 
 .Synopsis
  Get the Eula Link for for a Nav container or a Nav container image
 .Description
  Returns the Eula link for the version of Nav in the Nav container or Nav containerImage
  This is the Eula, which you accept when running the Nav Container using -e accept_eula=Y
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the Eula link
 .Example
  Get-NavContainerEula -containerOrImageName navserver
 .Example
  Get-NavContainerEula -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-NavContainerEula {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -eq 0) {
            throw "Container $containerOrImageName is not a NAV container"
        }
        return "$($inspect.Config.Labels.Eula)"
    }
}
Export-ModuleMember -function Get-NavContainerEula
