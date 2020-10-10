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
  if (Test-BcContainer -containerName devcontainer) { dosomething }
#>
function Test-BcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [switch] $doNotIncludeStoppedContainers
    )
    Process {
        if ($containerName) {
            $id = ""
            $a = "-a"
            if ($doNotIncludeStoppedContainers) {
                $a = ""
            }
    
            $id = docker ps $a -q --no-trunc --format "{{.ID}}/{{.Names}}" | Where-Object { $containerName -eq $_.split('/')[1] } | % { $_.split('/')[0] }
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
        else {
            $false
        }
    }
}
Set-Alias -Name Test-NavContainer -Value Test-BcContainer
Export-ModuleMember -Function Test-BcContainer -Alias Test-NavContainer
