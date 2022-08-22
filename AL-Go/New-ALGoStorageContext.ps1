function New-ALGoStorageContext {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $storageAccountName,
        [Parameter(Mandatory=$true, ParameterSetName = 'SasToken')]
        [string] $sasToken,
        [Parameter(Mandatory=$true, ParameterSetName = 'Key')]
        [string] $storageAccountKey,
        [Parameter(Mandatory=$false)]
        [string] $storageContainerName = '{project}',
        [Parameter(Mandatory=$false)]
        [string] $storageBlobName = '{version}/{project}-{type}.zip',
        [bool] $CD = $true,
        [switch] $skipTest
    )

    $storageContext = [ordered]@{
        "storageAccountName" = $storageAccountName
    }
    if ($sasToken) {
        $storageContext += @{ "sasToken" = $sasToken }
    }
    else {
        $storageContext += @{ "storageAccountKey" = $storageAccountKey }
    }
    $storageContext += [ordered]@{
        "containerName" = $storageContainerName.ToLowerInvariant()
        "blobName" = $storageBlobName.ToLowerInvariant()
        "CD" = $CD
    }

    if (!$skipTest) {
        Write-Host "Testing StorageContext"
        if (get-command New-AzureStorageContext -ErrorAction SilentlyContinue) {
            Write-Host "Using Azure.Storage PowerShell module"
        }
        else {
            if (!(get-command New-AzStorageContext -ErrorAction SilentlyContinue)) {
                throw "In order to test Storage Context, you need to have either the Azure.Storage or the Az.Storage PowerShell module installed."
            }
            Write-Host "Using Az.Storage PowerShell module"
            Set-Alias -Name New-AzureStorageContext -Value New-AzStorageContext
        }

        if ($storageContext.Contains('sastoken')) {
            $context = New-AzureStorageContext -StorageAccountName $storageContext.StorageAccountName -SasToken $storageContext.sastoken
        }
        else {
            $context = New-AzureStorageContext -StorageAccountName $storageContext.StorageAccountName -StorageAccountKey $storageContext.StorageAccountKey
        }

        'version','type','project' | ForEach-Object {
            if (-not $storageContext.blobName.Contains("{$_}")) {
                Write-Host -ForegroundColor Yellow "StorageBlobName is '$($storageContext.blobName)', should contain a reference to {$_} in the string"
            }
        }

        'project' | ForEach-Object {
            if (-not $storageContext.containerName.Contains("{$_}")) {
                Write-Host -ForegroundColor Yellow "StorageContainerName is '$($storageContext.ContainerName)', should contain a reference to {$_} in the string"
            }
        }

        Write-Host -ForegroundColor Green "StorageContext successfully validated"
    }

    $storageContext | ConvertTo-Json -Depth 99 -Compress
}
Export-ModuleMember -Function New-ALGoStorageContext
