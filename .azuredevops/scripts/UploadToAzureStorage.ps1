<#
.SYNOPSIS
    Uploads the BcContainerHelper zip file to Azure Storage.

.DESCRIPTION
    This script uploads the BcContainerHelper zip file to Azure Storage with two blob names:
    1. A versioned blob (e.g., "1.2.3.zip")
    2. A named blob ("latest.zip" for production releases or "preview.zip" for preview releases)

.PARAMETER StorageAccountName
    The name of the Azure Storage account.

.PARAMETER ContainerName
    The name of the storage container.

.PARAMETER ZipPath
    The full path to the zip file to upload.

.PARAMETER Version
    The version number to use for the versioned blob name.

.PARAMETER IsProductionRelease
    Whether this is a production release (uses "latest.zip") or preview release (uses "preview.zip").

.OUTPUTS
    Uploads two blobs to Azure Storage and outputs success message.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$ContainerName,

    [Parameter(Mandatory=$true)]
    [string]$ZipPath,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [bool]$IsProductionRelease
)

$errorActionPreference = "stop"

# Upload to Azure Storage as $version.zip
az storage blob upload `
    --account-name $StorageAccountName `
    --container-name $ContainerName `
    --name "$Version.zip" `
    --file $ZipPath `
    --auth-mode login `
    --overwrite

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload versioned blob $Version.zip"
}

# Upload to Azure Storage as latest.zip or preview.zip
if ($IsProductionRelease) {
    $blobName = "latest.zip"
}
else {
    $blobName = "preview.zip"
}

az storage blob upload `
    --account-name $StorageAccountName `
    --container-name $ContainerName `
    --name "$blobName" `
    --file $ZipPath `
    --auth-mode login `
    --content-cache-control "no-cache" `
    --overwrite

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload $blobName"
}

Write-Host "Successfully uploaded to Azure Storage (storage account: $StorageAccountName; container: $ContainerName) as $Version.zip and $blobName"
