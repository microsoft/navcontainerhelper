<# 
 .Synopsis
  Get a list of all NAV/BC Containers
 .Description
  Returns the names of all NAV/BC Containers
 .Example
  Get-NavContainers | Remove-NavContainer
#>
function Get-NavContainers {
    Process {
        docker ps --filter "label=nav" -a --format "{{.Names}}"
    }
}
Set-Alias -Name Get-BCContainers -Value Get-NavContainers
Export-ModuleMember -Function Get-NavContainers -Alias Get-BCContainers
