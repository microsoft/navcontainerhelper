<# 
 .Synopsis
  Stop a NAV/BC Container
 .Description
  Stop a Container
 .Parameter containerName
  Name of the container you want to stop
 .Example
  Stop-NavContainer -containerName devServer
#>
function Stop-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [string] $containerName
    )

    if (!(DockerDo -command stop -imageName $containerName)) {
        return
    }
}
Set-Alias -Name Stop-BCContainer -Value Stop-NavContainer
Export-ModuleMember -Function Stop-NavContainer -Alias Stop-BCContainer
