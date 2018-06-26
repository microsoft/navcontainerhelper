<# 
 .Synopsis
  Stop Nav container
 .Description
  Stop a Nav Container
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
        [string]$containerName
    )

    if (!(DockerDo -command stop -imageName $containerName)) {
        return
    }
}
Export-ModuleMember -function Stop-NavContainer
