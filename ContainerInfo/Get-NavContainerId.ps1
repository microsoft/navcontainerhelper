<# 
 .Synopsis
  Get the Id of a NAV/BC Container
 .Description
  Returns the Id of a Container based on the container name
  The Id returned is the full 64 digit container Id and the name must match
 .Parameter containerName
  Name of the container for which you want the Id
 .Example
  Get-BcContainerId -containerId navserver
#>
function Get-BcContainerId {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    Process {
        $id = ""
        docker ps --format "{{.ID}}:{{.Names}}" -a --no-trunc | ForEach-Object {
            $ps = $_.split(':')
            if ($containerName -eq $ps[1]) {
                $id = $ps[0]
            }
            if ($ps[0].StartsWith($containerName)) {
                if ($id) {
                    throw "Unambiguous container ID specified"
                }
                $id = $ps[0]
            }
        }
        if (!($id)) {
            throw "Container $containerName does not exist"
        }
        $id
    }
}
Set-Alias -Name Get-NavContainerId -Value Get-BcContainerId
Export-ModuleMember -Function Get-BcContainerId -Alias Get-NavContainerId
