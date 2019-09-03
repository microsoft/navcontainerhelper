<# 
 .Synopsis
  Get the IP Address of a NAV/BC Container
 .Description
  Inspect the Container and return the IP Address of the first network.
 .Parameter containerName
  Name of the container for which you want to get the IP Address
 .Parameter networkName
  Specify network name if you want to get the IP Address for a specific network
 .Example
  Get-NavContainerIpAddress -containerName navserver
#>
function Get-NavContainerIpAddress {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerName,
        [Parameter(Mandatory=$false)]
        [string] $networkName = ""
    )

    Process {

        $ip = Invoke-ScriptInNavContainer -containerName $containerName -scriptblock {
            $ip = ""
            $ips = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1" }
            if ($ips) {
                $ips | ForEach-Object {
                    if ("$ip" -eq "") {
                        $ip = $_.IPAddress
                    }
                }
            }
            $ip
        }

        if ("$ip" -eq "") {
            $inspect = docker inspect $containerName | ConvertFrom-Json
            $networks = $inspect.NetworkSettings.Networks
            $networks | get-member -MemberType NoteProperty | Select-Object Name | % {
                $name = $_.Name
                if (("$ip" -eq "") -and ("$networkName" -eq "" -or "$networkName" -eq "$name")) {
                    $network = $networks | Select-Object -ExpandProperty $name
                    $ip = $network.IPAddress
                }
            }
        }
        return $ip
    }
}
Set-Alias -Name Get-BCContainerIpAddress -Value Get-NavContainerIpAddress
Export-ModuleMember -Function Get-NavContainerIpAddress -Alias Get-BCContainerIpAddress
