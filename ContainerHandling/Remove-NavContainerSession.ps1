<# 
 .Synopsis
  Remove a PSSession for a NAV/BC Container
 .Description
  If a session exists in the session cache, it will be removed and disposed.
  Remove-BcContainer automatically removes sessions created.
 .Parameter containerName
  Name of the container for which you want to remove the session
 .Example
  Remove-BcContainerSession -containerName bcserver
#>
function Remove-BcContainerSession {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    Process {
        if ($sessions.ContainsKey($containerName)) {
            $session = $sessions[$containerName]
            try {
                $inspect = docker inspect $containerName | ConvertFrom-Json
                if ($inspect.HostConfig.Isolation -eq "process") {
                    $processID = Invoke-Command -Session $session -ScriptBlock { $PID }
                    Stop-Process -Id $processID -Force
                }
                else {

                    Remove-PSSession -Session $session
                }
            }
            catch {
                Remove-PSSession -Session $session
            }
            
            $sessions.Remove($containerName)
        }
    }
}
Set-Alias -Name Remove-NavContainerSession -Value Remove-BcContainerSession
Export-ModuleMember -Function Remove-BcContainerSession -Alias Remove-NavContainerSession
