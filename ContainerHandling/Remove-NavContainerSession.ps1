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
        foreach($configurationName in @('Microsoft.PowerShell','PowerShell.7')) {
            $cacheName = "$containerName-$configurationName"
            if ($sessions.ContainsKey($cacheName)) {
                $session = $sessions[$cacheName]
                try {
                    if ($killPsSessionProcess -and !$isInsideContainer) {
                        $inspect = docker inspect $containerName | ConvertFrom-Json
                        if ($inspect.HostConfig.Isolation -eq "process") {
                            try {
                                $processID = Invoke-Command -Session $session -ScriptBlock { $PID }
                                Stop-Process -Id $processID -Force
                            }
                            catch {
                                Write-Host "Error killing process in container"
                                Remove-PSSession -Session $session
                            }
                        }
                        else {
                            Remove-PSSession -Session $session
                        }
                    }
                    else {
                        Remove-PSSession -Session $session
                    }
                }
                catch {
                    Write-Host "Error removing session for container"
                }
                $sessions.Remove($cacheName)
            }
        }
    }
}
Set-Alias -Name Remove-NavContainerSession -Value Remove-BcContainerSession
Export-ModuleMember -Function Remove-BcContainerSession -Alias Remove-NavContainerSession
