<# 
 .Synopsis
  Runs a poor mans wizard to generate a container
 .Description
  Ask a number of questions to determine the parameters for a new container
#>
function New-NavContainerWizard {
    . (Join-Path $PSScriptRoot "..\CreateScript.ps1")
}
Set-Alias -Name New-BCContainerWizard -Value New-NavContainerWizard
Export-ModuleMember -Function New-NavContainerWizard -Alias New-BCContainerWizard
