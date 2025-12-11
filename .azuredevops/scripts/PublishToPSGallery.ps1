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
    if (-not $ApiKey) {
        throw "PowerShell Gallery API key not found"
    }

    # Publish to PowerShell Gallery
    Register-PSRepository -Default # Ensure the default repository is registered, PSGallery
    Publish-Module -Path $ModulePath -NuGetApiKey $ApiKey -SkipAutomaticTags

    Write-Host "Successfully published to PowerShell Gallery"
}
catch {
    Write-Host "##vso[task.logissue type=error]Error publishing to PowerShell Gallery. Error was $($_.Exception.Message)"
    exit 1
}
