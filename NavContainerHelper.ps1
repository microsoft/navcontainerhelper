Remove-Module NavContainerHelper -ErrorAction Ignore
$modulePath = Join-Path $PSScriptRoot "NavContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking
