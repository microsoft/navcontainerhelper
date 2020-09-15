<# 
 .Synopsis
  Get the name of the image used to run a NAV/BC Container
 .Description
  Get the name of the image used to run a Container
  The image name can be used to run a new instance of a Container with the same version of NAV/BC
 .Parameter containerName
  Name of the container for which you want to get the image name
 .Example
  $imageName = Get-BcContainerImageName -containerName bcserver
  PS C:\>Docker run -e accept_eula=Y $imageName
#>
function Get-BcContainerImageName {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        return "$($inspect.Config.Image)"
    }
}
Set-Alias -Name Get-NavContainerImageName -Value Get-BcContainerImageName
Export-ModuleMember -Function Get-BcContainerImageName -Alias Get-NavContainerImageName
