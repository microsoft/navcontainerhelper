<# 
 .Synopsis
  Open a new PowerShell session for a NAV/BC Container
 .Description
  Opens a new PowerShell window for a Container.
  The PowerShell prompt will have the PowerShell modules pre-loaded, meaning that you can use most PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to open a session
 .Parameter usePwsh
  If true, the powershell session opened will use pwsh instead of powershell (when BC version is 24 or later)
 .Example
  Open-BcContainer -containerName bcserver
#>
function Open-BcContainer {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [bool] $usePwsh = $bccontainerHelperConfig.usePwshForBc24
    )

    Process {
        $shell = 'powershell'
        try {
            $inspect = docker inspect $containerName | ConvertFrom-Json
            $version = [Version]$inspect.Config.Labels.version
            $vs = "Business Central"
            if ($version.Major -le 14) {
                $vs = "NAV"
            }
            if ($version.Major -ge 24 -and $usePwsh) {
                $shell = 'pwsh'
            }
            $psPrompt = """function prompt {'[$($containerName.ToUpperInvariant())] PS '+`$executionContext.SessionState.Path.CurrentLocation+('>'*(`$nestedPromptLevel+1))+' '}; Write-Host 'Welcome to the $vs Container PowerShell prompt'; Write-Host 'Microsoft Windows Version $($inspect.Config.Labels.osversion)'; Write-Host ""Windows PowerShell Version `$(`$PSVersionTable.psversion.ToString())""; Write-Host; . 'c:\run\prompt.ps1' -silent"""
        }
        catch {
            $psPrompt = """function prompt {'[$($containerName.ToUpperInvariant())] PS '+`$executionContext.SessionState.Path.CurrentLocation+('>'*(`$nestedPromptLevel+1))+' '}; . 'c:\run\prompt.ps1'"""
        }
        Start-Process "cmd.exe" @("/C";"docker exec -it $containerName $shell -noexit -command $psPrompt")
    }
}
Set-Alias -Name Open-NavContainer -Value Open-BcContainer
Export-ModuleMember -Function Open-BcContainer -Alias Open-NavContainer
