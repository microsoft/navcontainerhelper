<# 
 .Synopsis
  Get the application version from a NAV/BC Container or a NAV/BC Container image
 .Description
  Returns the version of NAV/BC in the format major.minor.build.release-country
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the version
 .Example
  Get-BcContainerNavVersion -containerOrImageName navserver
 .Example
  Get-BcContainerNavVersion -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-BcContainerNavVersion {
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
        return "$($inspect.Config.Labels.version)-$($inspect.Config.Labels.country)"
    }
}
Set-Alias -Name Get-NavContainerNavVersion -Value Get-BcContainerNavVersion
Export-ModuleMember -Function Get-BcContainerNavVersion -Alias Get-NavContainerNavVersion
