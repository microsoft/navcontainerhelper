<# 
 .Synopsis
  Runs a poor mans wizard to generate a container
 .Description
  Ask a number of questions to determine the parameters for a new container
#>
function New-NavContainerWizard {

    $pslink = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk"
    if (!(Test-Path $pslink)) {
        $pslink = "powershell.exe"
    }

    $script = Join-Path $PSScriptRoot "..\CreateScript.ps1"

    Start-Process $pslink @("-File ""$script""", "-skipContainerHelperCheck")

}
Set-Alias -Name New-BCContainerWizard -Value New-NavContainerWizard
Export-ModuleMember -Function New-NavContainerWizard -Alias New-BCContainerWizard
