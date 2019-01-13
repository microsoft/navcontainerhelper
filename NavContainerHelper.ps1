Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Remove-Module NavContainerHelper -ErrorAction Ignore
Uninstall-module NavContainerHelper -ErrorAction Ignore

$modulePath = Join-Path $PSScriptRoot "NavContainerHelper.psd1"
Import-Module $modulePath -DisableNameChecking
