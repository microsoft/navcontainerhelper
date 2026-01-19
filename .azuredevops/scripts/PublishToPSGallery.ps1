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
    # Publish to PowerShell Gallery
    # Ensure the default repository is registered, PSGallery
    if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
        Write-Host "PSGallery repository not found. Registering..."
        Register-PSRepository -Default -Verbose
    }

    # Verify PSGallery is properly configured
    $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction Stop
    Write-Host "PSGallery repository found:"
    Write-Host "  SourceLocation: $($psGallery.SourceLocation)"
    Write-Host "  PublishLocation: $($psGallery.PublishLocation)"
    Write-Host "  InstallationPolicy: $($psGallery.InstallationPolicy)"

    # Publish to PowerShell Gallery with explicit repository name
    Write-Host "Publishing module from: $ModulePath"
    Publish-Module -Path $ModulePath -NuGetApiKey $ApiKey -Repository 'PSGallery' -SkipAutomaticTags -Verbose

    Write-Host "Successfully published to PowerShell Gallery"
}
catch {
    Write-Host "##vso[task.logissue type=error]Error publishing to PowerShell Gallery. Error was $($_.Exception.Message)"
    Write-Host "##vso[task.logissue type=error]Full error details: $($_.Exception | Format-List * -Force | Out-String)"
    exit 1
}
