<# 
 .Synopsis
  Test whether a NAV/BC Container exists
 .Description
  Returns $true if a NAV/BC Container with the specified name exists
 .Parameter containerName
  Name of the container which you want to check for existence
 .Parameter doNotIncludeStoppedContainers
  Specify this parameter if you only want to test running containers
 .Example
  if (Test-NavContainer -containerName devcontainer) { dosomething }
#>
function Test-NavContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerName,

        [switch] $doNotIncludeStoppedContainers
    )
    Process {
        $id = ""
        $a = "-a"
        if ($doNotIncludeStoppedContainers) {
            $a = ""
        }
        $id = docker ps $a -q --no-trunc --filter "name=$containerName"
        if (!($id)) {
            $id = docker ps $a -q --no-trunc --filter "id=$containerName"
        }
        if ($id) {
            $inspect = docker inspect $id | ConvertFrom-Json
            ($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -ne 0 -and $inspect.Config.Labels.maintainer -eq "Dynamics SMB")
        } else {
            $false
        }
    }
}
Set-Alias -Name Test-BCContainer -Value Test-NavContainer
Export-ModuleMember -Function Test-NavContainer -Alias Test-BCContainer
