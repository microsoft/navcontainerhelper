<# 
 .Synopsis
  Remove a PSSession for a NAV/BC Container
 .Description
  If a session exists in the session cache, it will be removed and disposed.
  Remove-BcContainer automatically removes sessions created.
 .Parameter containerName
  Name of the container for which you want to remove the session
 .Parameter killPsSessionProcess
  When specifying this switch, the process of the PsSession will be removed using Stop-Process, instead of removing the session using Remove-PsSession (only for process isolation containers)
 .Example
  Remove-BcContainerSession -containerName bcserver
#>
function Remove-BcContainerSession {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [switch] $killPsSessionProcess = $bcContainerHelperConfig.KillPsSessionProcess
    )

    Process {
        if ($sessions.ContainsKey($containerName)) {
            $session = $sessions[$containerName]
            if ($killPsSessionProcess -and !$isInsideContainer) {
                $inspect = docker inspect $containerName | ConvertFrom-Json
                if ($inspect.HostConfig.Isolation -eq "process") {
                    $processID = Invoke-Command -Session $session -ScriptBlock { $PID }
                    Stop-Process -Id $processID -Force
                }
                else {
                    Remove-PSSession -Session $session
                }
            }
            else {
                Remove-PSSession -Session $session
            }
            
            $sessions.Remove($containerName)
        }
    }
}
Set-Alias -Name Remove-NavContainerSession -Value Remove-BcContainerSession
Export-ModuleMember -Function Remove-BcContainerSession -Alias Remove-NavContainerSession
