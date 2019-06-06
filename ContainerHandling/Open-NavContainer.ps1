<# 
 .Synopsis
  Open a new PowerShell session for a NAV/BC Container
 .Description
  Opens a new PowerShell window for a Container.
  The PowerShell prompt will have the PowerShell modules pre-loaded, meaning that you can use most PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to open a session
 .Example
  Open-NavContainer -containerName navserver
#>
function Open-NavContainer {
    [CmdletBinding()]
    Param
    (
        [string] $containerName = "navserver"
    )

    Process {
        Start-Process "cmd.exe" @("/C";"docker exec -it $containerName powershell -noexit C:\Run\prompt.ps1")
    }
}
Set-Alias -Name Open-BCContainer -Value Open-NavContainer
Export-ModuleMember -Function Open-NavContainer -Alias Open-BCContainer
