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
        $name = Get-NavContainerName $containerName
        if ($name) { $containerName = $name }

        $id = ""
        docker ps --format "{{.ID}}:{{.Names}}" -a --no-trunc | ForEach-Object {
            $ps = $_.split(':')
            if ($containerName -eq $ps[1]) {
                $id = $ps[0]
            }
        }
        if (!($id)) {
            throw "Container $containerName does not exist"
        }
        $id
    }
}
Export-ModuleMember -function Get-NavContainerId
