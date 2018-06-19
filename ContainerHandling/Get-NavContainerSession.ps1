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
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [switch]$silent
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
            Invoke-Command -Session $session -ScriptBlock { Param([bool]$silent)

                $runPath = "c:\Run"
                $myPath = Join-Path $runPath "my"

                function Get-MyFilePath([string]$FileName)
                {
                    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
                        (Join-Path $myPath $FileName)
                    } else {
                        (Join-Path $runPath $FileName)
                    }
                }

                . (Get-MyFilePath "prompt.ps1") -silent:$silent | Out-Null
                . (Get-MyFilePath "HelperFunctions.ps1") | Out-Null

                $txt2al = $NavIde.replace("finsql.exe","txt2al.exe")
                Set-Location $runPath
            } -ArgumentList $silent
            $sessions.Add($containerId, $session)
        }
        $sessions[$containerId]
    }
}
Export-ModuleMember -function Get-NavContainerSession
