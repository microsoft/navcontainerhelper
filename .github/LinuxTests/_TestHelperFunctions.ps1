$modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psd1"
Remove-Module BcContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking

$modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psm1"
Remove-Module BcContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking
