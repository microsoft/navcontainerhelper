<# 
 .Synopsis
  Get a list of all NAV/BC Containers
 .Description
  Returns the names of all NAV/BC Containers
 .Example
  Get-BcContainers | Remove-BcContainer
#>
function Get-BcContainers {
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
Set-Alias -Name Get-NavContainers -Value Get-BcContainers
Export-ModuleMember -Function Get-BcContainers -Alias Get-NavContainers
