<# 
 .Synopsis
  Get a list of all NAV Containers
 .Description
  Returns the names of all NAV Containers
 .Example
  Get-NavContainers | Remove-NavContainer
#>
function Get-NavContainers {
    Process {
        docker ps -a -q --no-trunc | ForEach-Object {
            $inspect = docker inspect $_ | ConvertFrom-Json
            if ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -ne 0) {
                $name = $inspect.Name
                if ($name.startsWith('/')) {
                    $name.subString(1)
                } else {
                    $name
                }
            }
        }
    }
}
Export-ModuleMember -function Get-NavContainers
