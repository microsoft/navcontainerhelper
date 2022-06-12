<# 
 .Synopsis
  Runs a poor mans wizard to generate an AL-Go for GitHub repo
 .Description
  Ask a number of questions to determine the parameters for a new AL-Go for GitHub repo
#>
function New-ALGoRepoWizard {

    $pslink = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk"
    if (!(Test-Path $pslink)) {
        $pslink = "powershell.exe"
    }

    $script = (Get-Item -Path (Join-Path $PSScriptRoot "..\CreateALGoRepo.ps1")).FullName

    $module = Get-InstalledModule -Name "BcContainerHelper" -ErrorAction SilentlyContinue

    Write-Host "Launching $script"

    if ($module) {
        Start-Process $pslink @("-File ""$script""", "")
    }
    else {
        . $script
    }


}
Export-ModuleMember -Function New-ALGoRepoWizard
