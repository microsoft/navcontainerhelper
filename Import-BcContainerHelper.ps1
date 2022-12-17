param(
    [switch] $Silent,
    [switch] $ExportTelemetryFunctions,
    [string[]] $bcContainerHelperConfigFile = @(),
    [switch] $useVolumes
)

if (($PSVersionTable.PSVersion -lt "6.0.0") -or $isWindows) {
    Get-ChildItem -Path $PSScriptRoot -Recurse | ForEach-Object { Unblock-File -Path $_.FullName }
}

$modules = @(
    "BCContainerHelper"
    "BC.HelperFunctions",
    "BC.ArtifactsHelper",
    "BC.AppSourceHelper",
    "BC.ALGoHelper",
    "BC.SaasHelper",
    "BC.NuGetHelper",
    "BC"
)

[Array]::Reverse($modules)
$modules | ForEach-Object { 
    Remove-Module $_ -ErrorAction SilentlyContinue
}
[Array]::Reverse($modules)

$modulePath = Join-Path $PSScriptRoot "$($modules[0]).psd1"
Import-Module $modulePath -DisableNameChecking -ArgumentList $Silent, $ExportTelemetryFunctions, $bcContainerHelperConfigFile, $useVolumes
