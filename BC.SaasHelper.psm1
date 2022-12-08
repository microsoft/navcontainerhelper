param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @()
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `
    -moduleDependencies @( 'BC.HelperFunctions' )

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# AppSource specific functions
. (Join-Path $PSScriptRoot "SaaS\Get-BcEnvironments.ps1")
. (Join-Path $PSScriptRoot "SaaS\Get-BcPublishedApps.ps1")
. (Join-Path $PSScriptRoot "SaaS\Get-BcInstalledExtensions.ps1")
. (Join-Path $PSScriptRoot "SaaS\Install-BcAppFromAppSource")
. (Join-Path $PSScriptRoot "SaaS\Publish-PerTenantExtensionApps.ps1")
. (Join-Path $PSScriptRoot "SaaS\New-BcEnvironment.ps1")
. (Join-Path $PSScriptRoot "SaaS\Remove-BcEnvironment.ps1")
. (Join-Path $PSScriptRoot "SaaS\Set-BcEnvironmentApplicationInsightsKey.ps1")
. (Join-Path $PSScriptRoot "SaaS\Get-BcDatabaseExportHistory.ps1")
. (Join-Path $PSScriptRoot "SaaS\New-BcDatabaseExport.ps1")
. (Join-Path $PSScriptRoot "SaaS\Get-BcScheduledUpgrade.ps1")
. (Join-Path $PSScriptRoot "SaaS\Reschedule-BcUpgrade.ps1")
