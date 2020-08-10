<# 
 .Synopsis
  Get the Legal Link for for a NAV/BC Container or a NAV/BC Container image
 .Description
  Returns the Legal link for the version of NAV or Business Central in the Container or Container Image
  This is the legal agreement for running this version of NAV or Business Central
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the legal link
 .Example
  Get-BcContainerLegal -containerOrImageName bcserver
 .Example
  Get-BcContainerLegal -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-BcContainerLegal {
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
        return "$($inspect.Config.Labels.legal)"
    }
}
Set-Alias -Name Get-NavContainerLegal -Value Get-BcContainerLegal
Export-ModuleMember -Function Get-BcContainerLegal -Alias Get-NavContainerLegal
