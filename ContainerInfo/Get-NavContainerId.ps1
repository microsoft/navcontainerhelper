<# 
 .Synopsis
  Get the Id of a Nav container
 .Description
  Returns the Id of a Nav container based on the container name
  The Id returned is the full 64 digit container Id and the name must match
 .Parameter containerName
  Name of the container for which you want the Id
 .Example
  Get-NavContainerId -containerId navserver
#>
function Get-NavContainerId {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $id = ""
        docker ps --filter name="$containerName" -a -q --no-trunc | ForEach-Object {
            # filter only filters on the start of the name
            $name = Get-NavContainerName -containerId $_
            if ($name -eq $containerName) {
                $id = $_
            }
        }
        if (!($id)) {
            throw "Container $containerName does not exist"
        }
        $id
    }
}
Export-ModuleMember -function Get-NavContainerId
