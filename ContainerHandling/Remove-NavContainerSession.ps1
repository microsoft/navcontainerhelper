<# 
 .Synopsis
  Remove a PSSession for a Nav Container
 .Description
  If a session exists in the session cache, it will be removed and disposed.
  Remove-NavContainer automatically removes sessions created.
 .Parameter containerName
  Name of the container for which you want to remove the session
 .Example
  Remove-NavContainerSession -containerName navserver
#>
function Remove-NavContainerSession {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [string]$containerName
    )

    Process {
        $containerId = Get-NavContainerId -containerName $containerName

        if ($sessions.ContainsKey($containerId)) {
            $session = $sessions[$containerId]
            Remove-PSSession -Session $session
            $sessions.Remove($containerId)
        }
    }
}
Export-ModuleMember -function Remove-NavContainerSession
