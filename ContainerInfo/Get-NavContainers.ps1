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
        docker ps --filter "label=nav" -a --format "{{.Names}}"
    }
}
Export-ModuleMember -Function * -Alias *
