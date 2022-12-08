param(
    [switch] $Silent,
    [switch] $ExportTelemetryFunctions,
    [string[]] $bcContainerHelperConfigFile = @(),
    [switch] $useVolumes
)

Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Remove-Module NavContainerHelper -ErrorAction SilentlyContinue
Remove-Module BcContainerHelper -ErrorAction SilentlyContinue
Remove-Module BC.NuGetHelper -ErrorAction SilentlyContinue
Remove-Module BC.SaasHelper -ErrorAction SilentlyContinue
Remove-Module BC.ALGoHelper -ErrorAction SilentlyContinue
Remove-Module BC.AppSourceHelper -ErrorAction SilentlyContinue
Remove-Module BC.ArtifactsHelper -ErrorAction SilentlyContinue
Remove-Module BC.HelperFunctions -ErrorAction SilentlyContinue

$modulePath = Join-Path $PSScriptRoot "BcContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking -ArgumentList $Silent, $ExportTelemetryFunctions, $bcContainerHelperConfigFile, $useVolumes
