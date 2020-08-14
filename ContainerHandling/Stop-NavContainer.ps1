<# 
 .Synopsis
  Stop a NAV/BC Container
 .Description
  Stop a Container
 .Parameter containerName
  Name of the container you want to stop
 .Example
  Stop-BcContainer -containerName devServer
#>
function Stop-BcContainer {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    if (!(DockerDo -command stop -imageName $containerName)) {
        return
    }
}
Set-Alias -Name Stop-NavContainer -Value Stop-BcContainer
Export-ModuleMember -Function Stop-BcContainer -Alias Stop-NavContainer
