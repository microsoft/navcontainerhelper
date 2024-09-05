﻿<# 
 .Synopsis
  Enter PowerShell session in a NAV/BC Container
 .Description
  Use the current PowerShell prompt to enter a PowerShell session in a Container.
  Especially useful in PowerShell ISE, where you after entering a session, can use PSEdit to edit files inside the container.
  The PowerShell session will have the PowerShell modules pre-loaded, meaning that you can use most PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Example
  Enter-BcContainer -containerName
  [64b6ca872aefc93529bdfc7ec0a4eb7a2f0c022942000c63586a48c27b4e7b2d]: PS C:\run>psedit c:\run\navstart.ps1
#>
function Enter-BcContainer {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    Process {
        if ($bcContainerHelperConfig.usePsSession) {
            try {
                $session = Get-BcContainerSession -containerName $containerName -silent
            }
            catch {
                $session = $null
            }
        }
        if ($session) {
            Enter-PSSession -Session $session
            if ($session.ComputerType -eq 'Container') {
                Invoke-Command -Session $session -ScriptBlock {
                    function prompt {"[$env:COMPUTERNAME]: PS5 $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "}
                }
            }
        }
        else {
            Write-Host "Could not create a session, running Open-BcContainer instead"
            Open-BcContainer $containerName
        }
    }
}
Set-Alias -Name Enter-NavContainer -Value Enter-BcContainer
Export-ModuleMember -Function Enter-BcContainer -Alias Enter-NavContainer
