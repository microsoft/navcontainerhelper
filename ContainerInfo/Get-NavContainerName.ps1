<# 
 .Synopsis
  Get the name of a Nav container
 .Description
  Returns the name of a Nav container based on the container Id
  You need to specify enought characters of the Id to make it unambiguous
 .Parameter containerId
  Id (or part of the Id) of the container for which you want to get the name
 .Example
  Get-NavContainerName -containerId 7d
#>
function Get-NavContainerName {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerId
    )

    docker ps --format='{{.Names}}' -a --filter "id=$containerId"
}
Export-ModuleMember -function Get-NavContainerName
