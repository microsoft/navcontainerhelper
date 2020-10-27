<# 
 .Synopsis
  Preview function for publishing build output to storage account
 .Description
  Preview function for publishing build output to storage account
#>
function Publish-BuildOutputToStorage {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $StorageConnectionString,
        [Parameter(Mandatory=$true)]
        [string] $projectName,
        [Parameter(Mandatory=$true)]
        [string] $appVersion,
        [Parameter(Mandatory=$false)]
        [string] $permission = "Container",
        [Parameter(Mandatory=$true)]
        [string] $path,
        [switch] $setLatest
    )

    if (!(get-command New-AzureStorageContext -ErrorAction SilentlyContinue)) {
        Set-Alias -Name New-AzureStorageContext -Value New-AzStorageContext
        Set-Alias -Name New-AzureStorageContainer -Value New-AzStorageContainer
        Set-Alias -Name Set-AzureStorageBlobContent -Value Set-AzStorageBlobContent
    }

    $storageContext = New-AzureStorageContext -ConnectionString $StorageConnectionString
    New-AzureStorageContainer -Name $projectName -Context $storageContext -Permission $permission -ErrorAction Ignore | Out-Null

    "RuntimePackages", "Apps", "TestApps" | % {
        if (Test-Path (Join-Path $path "$_\*")) {
            $tempFile = Join-Path $ENV:TEMP "$([Guid]::newguid().ToString()).zip"
            Compress-Archive -path (Get-Item (Join-Path $path $_)).FullName -DestinationPath $tempFile
            Set-AzureStorageBlobContent -File $tempFile -Context $storageContext -Container $projectName -Blob "$appVersion/$_.zip".ToLowerInvariant() -Force | Out-Null
            if ($setLatest) {
                Set-AzureStorageBlobContent -File $tempFile -Context $storageContext -Container $projectName -Blob "latest/$_.zip".ToLowerInvariant() -Force | Out-Null
            }
            Remove-Item $tempFile -Force
        }
    }
}
Export-ModuleMember -Function Publish-BuildOutputToStorage
