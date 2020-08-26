Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Remove-Module NavContainerHelper -ErrorAction Ignore
Remove-Module BcContainerHelper -ErrorAction Ignore
Uninstall-module NavContainerHelper -ErrorAction Ignore
Uninstall-module BcContainerHelper -ErrorAction Ignore

$modulePath = Join-Path $PSScriptRoot "BcContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking
