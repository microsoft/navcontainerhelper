<# 
 .Synopsis
  Get a list of folders shared with a Nav container
 .Description
  Returns a hastable of folders shared with the container.
  The name in the hashtable is the local folder, the value is the folder inside the container
 .Parameter containerName
  Name of the container for which you want to get the shared folder list
 .Example
  Get-NavContainerSharedFolders -containerName navserver
 .Example
  (Get-NavContainerSharedFolders -containerName navserver)["c:\programdata\navcontainerhelper"]
 .Example
  ((Get-NavContainerSharedFolders -containerName navserver).GetEnumerator() | Where-Object { $_.Value -eq "c:\run\my" }).Key
#>
function Get-NavContainerSharedFolders {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        $sharedFolders = @{}
        if ($inspect.HostConfig.Binds) {
            $inspect.HostConfig.Binds | ForEach-Object {
                $idx = $_.IndexOf(':', $_.IndexOf(':') + 1)
                $sharedFolders += @{$_.Substring(0, $idx) = $_.SubString($idx+1) }
            }
        }
        return $sharedFolders
    }
}
Export-ModuleMember -function Get-NavContainerSharedFolders
