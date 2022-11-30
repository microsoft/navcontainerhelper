param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @()
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `
    -moduleDependencies @( 'BC.ConfigurationHelper' )

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$telemetry = @{
    "Assembly" = $null
    "PartnerClient" = $null
    "MicrosoftClient" = $null
    "CorrelationId" = ""
    "TopId" = ""
    "Debug" = $false
}
try {
    if (($bcContainerHelperConfig.MicrosoftTelemetryConnectionString) -and !$Silent) {
        Write-Host -ForegroundColor Green 'BC.TelemetryHelper emits usage statistics telemetry to Microsoft'
    }
    $dllPath = "C:\ProgramData\BcContainerHelper\Microsoft.ApplicationInsights.2.15.0.44797.dll"
    if (-not (Test-Path $dllPath)) {
        Copy-Item (Join-Path $PSScriptRoot "Microsoft.ApplicationInsights.dll") -Destination $dllPath
    }
    $telemetry.Assembly = [System.Reflection.Assembly]::LoadFrom($dllPath)
} catch {
    if (!$Silent) {
        Write-Host -ForegroundColor Yellow "Unable to load ApplicationInsights.dll"
    }
}

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")
. (Join-Path $PSScriptRoot "TelemetryHelper.ps1")

# Telemetry functions
Export-ModuleMember -Function RegisterTelemetryScope
Export-ModuleMember -Function InitTelemetryScope
Export-ModuleMember -Function AddTelemetryProperty
Export-ModuleMember -Function TrackTrace
Export-ModuleMember -Function TrackException
