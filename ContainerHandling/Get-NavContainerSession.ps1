<# 
 .Synopsis
  Get (or create) a PSSession for a Nav Container
 .Description
  Checks the session cache for an existing session. If a session exists, it will be reused.
  If no session exists, a new session will be created.
 .Parameter containerName
  Name of the container for which you want to create a session
 .Example
  $session = Get-NavContainerSession -containerName navserver
  PS C:\>Invoke-Command -Session $session -ScriptBlock { Set-NavServerInstance -ServerInstance NAV -restart }
#>
function Get-NavContainerSession {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $containerId = Get-NavContainerId -containerName $containerName

        if ($sessions.ContainsKey($containerId)) {
            $session = $sessions[$containerId]
            try {
                $ok = Invoke-Command -Session $session -ScriptBlock { $true }
            }
            catch {
                Remove-PSSession -Session $session
                $sessions.Remove($containerId)
            }
        }
        if (!($sessions.ContainsKey($containerId))) {
            $session = New-PSSession -ContainerId $containerId -RunAsAdministrator
            Invoke-Command -Session $session -ScriptBlock {
                . "c:\run\prompt.ps1" | Out-Null
                . "c:\run\HelperFunctions.ps1" | Out-Null

                $txt2al = $NavIde.replace("finsql.exe","txt2al.exe")
                cd c:\run
            }
            $sessions.Add($containerId, $session)
        }
        $sessions[$containerId]
    }
}
Export-ModuleMember -function Get-NavContainerSession
