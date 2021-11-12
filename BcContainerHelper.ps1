param(
    [switch] $Silent,
    [switch] $ExportTelemetryFunctions,
    [string[]] $bcContainerHelperConfigFile = @(),
    [switch] $useVolumes
)

Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Remove-Module NavContainerHelper -ErrorAction Ignore
Remove-Module BcContainerHelper -ErrorAction Ignore

if ($useVolumes) {
Write-Host "USE VOLUMES1"
}

$modulePath = Join-Path $PSScriptRoot "BcContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking -ArgumentList $Silent, $ExportTelemetryFunctions, $bcContainerHelperConfigFile, $useVolumes
