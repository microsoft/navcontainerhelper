<# 
 .Synopsis
  Get a list of all NAV/BC Containers
 .Description
  Returns the names of all NAV/BC Containers
 .Example
  Get-NavContainers | Remove-NavContainer
#>
function Get-NavContainers {
    Param (
        [switch] $includeLabels
    )

    Process {
        if ($includeLabels) {
            $containers = @()
            docker ps --filter "label=nav" -a --no-trunc --format 'name={{.Names}},id={{.ID}},image={{.Image}},createdat={{.CreatedAt}},runningfor={{.RunningFor}},size={{.Size}},status={{.Status}},{{.Labels}}' | % {
                $labels = [PSCustomObject]@{}
                $_.Split(',') | % {
                    $name = $_.Split('=')[0]
                    $value = $_.SubString($name.length+1)
                    $labels | Add-Member -NotePropertyName $name -NotePropertyValue $value
                } 
                $containers += $labels
            }
        }
        else {
            $containers = docker ps --filter "label=nav" -a --format '{{.Names}}'
        }
        $containers            
    }
}
Set-Alias -Name Get-BCContainers -Value Get-NavContainers
Export-ModuleMember -Function Get-NavContainers -Alias Get-BCContainers
