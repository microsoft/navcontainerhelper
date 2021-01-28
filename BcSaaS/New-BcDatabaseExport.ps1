<# 
 .Synopsis
  Function for creating a starting a new Database Export from an online Business Central environment
 .Description
  Function for creating a starting a new Database Export from an online Business Central environment
  Wrapper for https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api#start-environment-database-export
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Environment from which you want to return the published Apps.
 .Parameter storageAccountSasUri
  An Azure SAS uri pointing at the Azure storage account where the database will be exported to. The uri must have (Read | Write | Create | Delete) permissions
 .Parameter blobContainerName
  The name of the container that will be created by the process to store the exported database.
 .Parameter blobName
  The name of the blob within the container that the database will be exported to. Databases are exported in the .bacpac format so a filename ending with the '.bacpac' suffix is typical.
 .Parameter doNotWait
  Include this flag if you do not want to wait for the backup to complete
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  New-BcDatabaseExport -bcAuthContext $authContext -environment "Production" -storageAccountSasUri $storageAccountSasUri -blobContainerName $blobContainerName -blobName $blobName -doNotWait
#>
function New-BcDatabaseExport {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$true)]
        [string] $storageAccountSasUri,
        [Parameter(Mandatory=$true)]
        [string] $blobContainerName,
        [Parameter(Mandatory=$true)]
        [string] $blobName,
        [switch] $doNotWait
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }
    $body = @{
        "storageAccountSasUri" = $storageAccountSasUri
        "container" = $blobContainerName
        "blob" = $blobName
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method POST -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/exports/applications/$applicationFamily/environments/$environment" -Headers $headers -Body $Body -ContentType 'application/json' -UseBasicParsing
    }
    catch {
        throw (GetExtenedErrorMessage $_.Exception)
    }
    if (!$doNotWait) {
        $uri = [Uri]::new($storageAccountSasUri)
        $blobUrl = "$($uri.Scheme)://$($uri.Host)/$blobContainerName/$blobName$($uri.Query)"
        $done = $false
        Write-Host -NoNewline "Waiting for backup to complete."
        while (!$done) {
            Start-Sleep -Seconds 30
            Write-Host -NoNewline "."
            try {
                $result = Invoke-WebRequest -UseBasicParsing -Method Head -Uri $blobUrl -ErrorAction SilentlyContinue
                if ($result.StatusCode -eq 200) {
                    Write-Host -ForegroundColor Green " Success"
                    $done = $true
                }
                else {
                    Write-Host -ForegroundColor red " Failure"
                    throw $result.StatusDescription
                }
            }
            catch {
                if ($_.exception.response.StatusCode -ne "NotFound") {
                    Write-Host -ForegroundColor red " Failure"
                    throw
                }
            }
        }
    }
}
Export-ModuleMember -Function New-BcDatabaseExport
