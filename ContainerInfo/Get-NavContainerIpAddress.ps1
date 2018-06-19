<# 
 .Synopsis
  Get the IP Address of a Nav container
 .Description
  Inspect the Nav Container and return the IP Address of the first network.
 .Parameter containerName
  Name of the container for which you want to get the IP Address
 .Example
  Get-NavContainerIpAddress -containerName navserver
#>
function Get-NavContainerIpAddress {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        $networks = $inspect.NetworkSettings.Networks
        $network = ($networks | get-member -MemberType NoteProperty | Select-Object Name).Name
        return ($networks | Select-Object -ExpandProperty $network).IPAddress
    }
}
Export-ModuleMember -function Get-NavContainerIpAddress
