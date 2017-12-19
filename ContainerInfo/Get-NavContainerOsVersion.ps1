<# 
 .Synopsis
  Get the OS Version for a Nav container or a Nav container image
 .Description
  Returns the version of the WindowsServerCore image used to build the Nav container or Nav containerImage
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the OS Version
 .Example
  Get-NavContainerOsVersion -containerOrImageName navserver
 .Example
  Get-NavContainerOsVersion -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-NavContainerOsVersion {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        # returns empty with generic tag 0.0.2.3 or earlier
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -eq 0) {
            throw "Container $containerOrImageName is not a NAV container"
        }
        return "$($inspect.Config.Labels.osversion)"
    }
}
Export-ModuleMember -function Get-NavContainerOsVersion
