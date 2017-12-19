<# 
 .Synopsis
  Get the Legal Link for for a Nav container or a Nav container image
 .Description
  Returns the Legal link for the version of Nav in the Nav container or Nav containerImage
  This is the legal agreement for running this version of Microsoft Dynamics NAV
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the legal link
 .Example
  Get-NavContainerLegal -containerOrImageName navserver
 .Example
  Get-NavContainerLegal -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-NavContainerLegal {
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
        return "$($inspect.Config.Labels.legal)"
    }
}
Export-ModuleMember -function Get-NavContainerLegal
