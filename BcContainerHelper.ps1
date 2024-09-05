param(
    [switch] $Silent,
    [switch] $ExportTelemetryFunctions,
    [string[]] $bcContainerHelperConfigFile = @(),
    [switch] $useVolumes
)

. (Join-Path $PSScriptRoot 'Import-BcContainerHelper.ps1') -Silent:$silent -ExportTelemetryFunctions:$ExportTelemetryFunctions -bcContainerHelperConfigFile $bcContainerHelperConfigFile -useVolumes:$useVolumes
