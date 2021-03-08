<# 
 .Synopsis
  Function for publishing build output from Run-AlPipeline to storage account
 .Description
  Function for publishing build output to storage account
  The function will publish artifacts in the format of https://businesscentralapps.blob.core.windows.net/bingmaps/16.0.10208.0/apps.zip
  Please consult the CI/CD Workshop document at http://aka.ms/cicdhol to learn more about this function
 .Parameter StorageConnectionString
  A connectionstring with access to the storage account in which you want to publish artifacts (SecureString or String)
 .Parameter projectName
  Project name of the app you want to publish. This becomes part of the blob url.
 .Parameter appVersion
  Version of the app you want to publish. This becomes part of the blob url.
 .Parameter permission
  Specifies the public level access to the container (if it gets created by this function)
  Default is Container, which provides full access. Other values are Blob or Off.
 .Parameter path
  Path containing the build output from Run-AlPipeline.
  The content of folders Apps, RuntimePackages and TestApps from this folder is published.
 .Parameter setLatest
  Add this switch if you want this artifact to also be published as latest
#>
function Publish-BuildOutputToStorage {
    Param(
        [Parameter(Mandatory=$true)]
        $StorageConnectionString,
        [Parameter(Mandatory=$true)]
        [string] $projectName,
        [Parameter(Mandatory=$true)]
        [string] $appVersion,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Container','Blob','Off')]
        [string] $permission = "Container",
        [Parameter(Mandatory=$true)]
        [string] $path,
        [switch] $setLatest
    )

    if ($StorageConnectionString -is [SecureString]) { $StorageConnectionString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($StorageConnectionString)) }
    if ($StorageConnectionString -isnot [string]) { throw "StorageConnectionString needs to be a SecureString or a String" }
    $projectName = $projectName.ToLowerInvariant()
    $appVersion = $appVersion.ToLowerInvariant()

    if (!(get-command New-AzureStorageContext -ErrorAction SilentlyContinue)) {
        Set-Alias -Name New-AzureStorageContext -Value New-AzStorageContext
        Set-Alias -Name New-AzureStorageContainer -Value New-AzStorageContainer
        Set-Alias -Name Set-AzureStorageBlobContent -Value Set-AzStorageBlobContent
    }

    $storageContext = New-AzureStorageContext -ConnectionString $StorageConnectionString
    New-AzureStorageContainer -Name $projectName -Context $storageContext -Permission $permission -ErrorAction Ignore | Out-Null

    "RuntimePackages", "Apps", "TestApps" | % {
        if (Test-Path (Join-Path $path "$_\*")) {
            $tempFile = Join-Path (Get-TempDir) "$([Guid]::newguid().ToString()).zip"
            try {
                Compress-Archive -path (Get-Item (Join-Path $path $_)).FullName -DestinationPath $tempFile
                Set-AzureStorageBlobContent -File $tempFile -Context $storageContext -Container $projectName -Blob "$appVersion/$_.zip".ToLowerInvariant() -Force | Out-Null
                if ($setLatest) {
                    Set-AzureStorageBlobContent -File $tempFile -Context $storageContext -Container $projectName -Blob "latest/$_.zip".ToLowerInvariant() -Force | Out-Null
                }
            } finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }  
        }
    }
}
Export-ModuleMember -Function Publish-BuildOutputToStorage
