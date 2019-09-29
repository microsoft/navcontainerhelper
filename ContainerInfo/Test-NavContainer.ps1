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
        $name = Get-NavContainerName $containerName
        if ($name) { $containerName = $name }
        $id = ""
        $a = "-a"
        if ($doNotIncludeStoppedContainers) {
            $a = ""
        }
        docker ps $a -q --no-trunc | ForEach-Object {
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
Set-Alias -Name Test-BCContainer -Value Test-NavContainer
Export-ModuleMember -Function Test-NavContainer -Alias Test-BCContainer
