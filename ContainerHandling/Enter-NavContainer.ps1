<# 
 .Synopsis
  Enter PowerShell session in Nav Container
 .Description
  Use the current PowerShell prompt to enter a PowerShell session in a Nav Container.
  Especially useful in PowerShell ISE, where you after entering a session, can use PSEdit to edit files inside the container.
  The PowerShell session will have the Nav PowerShell modules pre-loaded, meaning that you can use most Nav PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Example
  Enter-NavContainer -containerName
  [64b6ca872aefc93529bdfc7ec0a4eb7a2f0c022942000c63586a48c27b4e7b2d]: PS C:\run>psedit c:\run\navstart.ps1
#>
function Enter-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $session = Get-NavContainerSession $containerName
        Enter-PSSession -Session $session
        Invoke-Command -Session $session -ScriptBlock {
            function prompt {"[$env:COMPUTERNAME]: PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "}
        }
    }
}
Export-ModuleMember -function Enter-NavContainer
