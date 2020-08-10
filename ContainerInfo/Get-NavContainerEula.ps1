<# 
 .Synopsis
  Get the Eula Link for for a NAV/BC Container or a NAV/BC Container image
 .Description
  Returns the Eula link for the version of NAV or Business Central in the Container or Container Image
  This is the Eula, which you accept when running the Container using -e accept_eula=Y
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the Eula link
 .Example
  Get-BcContainerEula -containerOrImageName bcserver
 .Example
  Get-BcContainerEula -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-BcContainerEula {
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
        return "$($inspect.Config.Labels.Eula)"
    }
}
Set-Alias -Name Get-NavContainerEula -Value Get-BcContainerEula
Export-ModuleMember -Function Get-BcContainerEula -Alias Get-NavContainerEula
