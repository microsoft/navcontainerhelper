<#
.SYNOPSIS
    Publishes the BcContainerHelper module to PowerShell Gallery.

.DESCRIPTION
    This script publishes the BcContainerHelper module to the PowerShell Gallery using the provided API key.
    It registers the default PSGallery repository if needed and publishes the module.

.PARAMETER ModulePath
    The path to the BcContainerHelper module directory to publish.

.PARAMETER ApiKey
    The PowerShell Gallery API key for authentication.

.OUTPUTS
    Publishes the module to PowerShell Gallery and outputs success message.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ModulePath,

    [Parameter(Mandatory=$true)]
    [string]$ApiKey
)

$errorActionPreference = "stop"

try {
    # Publish to PowerShell Gallery using PSResourceGet
    # Ensure the default repository is registered, PSGallery
    if (-not (Get-PSResourceRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
        Write-Host "PSGallery repository not found. Registering..."
        Register-PSResourceRepository -PSGallery -Verbose
    }

    # Verify PSGallery is properly configured
    $psGallery = Get-PSResourceRepository -Name 'PSGallery' -ErrorAction Stop
    Write-Host "PSGallery repository found:"
    Write-Host "  Uri: $($psGallery.Uri)"
    Write-Host "  Trusted: $($psGallery.Trusted)"

    # Publish to PowerShell Gallery with explicit repository name
    # Use the specific module manifest to avoid publishing nested/sub-modules
    $moduleManifestPath = Join-Path $ModulePath 'BcContainerHelper.psd1'
    if (-not (Test-Path $moduleManifestPath)) {
        throw "Module manifest not found at: $moduleManifestPath"
    }
    Write-Host "Publishing module from: $ModulePath (manifest: $moduleManifestPath)"
    Publish-PSResource -Path $moduleManifestPath -ApiKey $ApiKey -Repository 'PSGallery' -SkipModuleManifestValidate -Verbose

    Write-Host "Successfully published to PowerShell Gallery"
}
catch {
    Write-Host "##vso[task.logissue type=error]Error publishing to PowerShell Gallery. Error was $($_.Exception.Message)"
    Write-Host "##vso[task.logissue type=error]Full error details: $($_.Exception | Format-List * -Force | Out-String)"
    exit 1
}
