<# 
 .Synopsis
  Runs a poor mans wizard to generate a container
 .Description
  Ask a number of questions to determine the parameters for a new container
#>
function New-BcContainerWizard {

    $pslink = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk"
    if (!(Test-Path $pslink)) {
        $pslink = "powershell.exe"
    }

    $script = Join-Path $PSScriptRoot "..\CreateScript.ps1"

    Start-Process $pslink @($script, "-skipContainerHelperCheck")

}
Set-Alias -Name New-NavContainerWizard -Value New-BcContainerWizard
Export-ModuleMember -Function New-BcContainerWizard -Alias New-NavContainerWizard
