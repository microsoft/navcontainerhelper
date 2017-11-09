<# 
 .Synopsis
  Open a new PowerShell session for a Nav Container
 .Description
  Opens a new PowerShell window for a Nav Container.
  The PowerShell prompt will have the Nav PowerShell modules pre-loaded, meaning that you can use most Nav PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to open a session
 .Example
  Open-NavContainer -containerName navserver
#>
function Open-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        Start-Process "cmd.exe" @("/C";"docker exec -it $containerName powershell -noexit C:\Run\prompt.ps1")
    }
}
Export-ModuleMember -function Open-NavContainer
