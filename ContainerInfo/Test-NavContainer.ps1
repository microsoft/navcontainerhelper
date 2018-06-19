<# 
 .Synopsis
  Test whether a Nav container exists
 .Description
  Returns $true if the Nav container with the specified name exists
 .Parameter containerName
  Name of the container which you want to check for existence
 .Example
  if (Test-NavContainer -containerName devcontainer) { dosomething }
#>
function Test-NavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    Process {
        $name = Get-NavContainerName $containerName
        if ($name) { $containerName = $name }
        $id = ""
        docker ps --filter name="$containerName" -a -q --no-trunc | ForEach-Object {
            $name = Get-NavContainerName -containerId $_
            if ($name -eq $containerName) {
                $id = $_
            }
        }
        if ($id) {
            $inspect = docker inspect $id | ConvertFrom-Json
            ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -ne 0)
        } else {
            $false
        }
    }
}
Export-ModuleMember -function Test-NavContainer
