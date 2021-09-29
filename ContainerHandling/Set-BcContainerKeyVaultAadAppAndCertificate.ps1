<# 
 .Synopsis
  Import Certificate for Keyvault access to a BC Container
 .Description
  Import Certificate for Keyvault access to a BC Container
 .Parameter containerName
  Name of the container in which you want to import a certificate
 .Parameter pfxFile
  Path or secure url to the pfx certificate file which gives access to AAD app with clientId
 .Parameter pfxPassword
  Password for pfx certificate file which gives access to AAD app with clientId
 .Parameter clientId
  clientId of AAD app with access to Key Vault used in apps
 .Parameter enablePublisherValidation
  include this switch to disallow access to keyvault when running from VS Code (include for production)
 .Parameter doNotRestartServiceTier
  set this switch to defer restart of service tier
 .Example
  Set-BcContainerKeyVaultAadAppAndCertificate -containerName $containerName -pfxFile $pfxFile -pfxPassword $pfxPassword -clientId $clientId
#>
function Set-BcContainerKeyVaultAadAppAndCertificate {
    Param(
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$true)]
        [string] $pfxFile,
        [Parameter(Mandatory=$true)]
        [SecureString] $pfxPassword,
        [Parameter(Mandatory=$true)]
        [string] $clientId,
        [switch] $enablePublisherValidation,
        [switch] $doNotRestartServiceTier
    )
    
$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $ExtensionsFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions"
    $sharedPfxFile = Join-Path $ExtensionsFolder "$containerName\my\$([GUID]::NewGuid().ToString()).pfx"
    $removeSharedPfxFile = $true
    if ($pfxFile -like "https://*" -or $pfxFile -like "http://*") {
        Write-Host "Downloading certificate file to container"
        (New-Object System.Net.WebClient).DownloadFile($pfxFile, $sharedPfxFile)
    }
    else {
        if (Get-BcContainerPath -containerName $containerName -path $pfxFile) {
            $sharedPfxFile = $pfxFile
            $removeSharedPfxFile = $false
        }
        else {
            Write-Host "Copying certificate file to container"
            Copy-Item -Path $pfxFile -Destination $sharedPfxFile -Force
        }
    }

    try {
        TestPfxCertificate -pfxFile $sharedPfxFile -pfxPassword $pfxPassword
    
        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($pfxFile, $pfxPassword, $clientId, $enablePublisherValidation, $doNotRestartServiceTier)
    
            # Set AzureKeyVaultAppSecretsPublisherValidationEnabled to false to avoid having to publish with PublisherAzureActiveDirectoryTenantId
            Set-NAVServerConfiguration -ServerInstance $serverInstance -KeyName "AzureKeyVaultAppSecretsPublisherValidationEnabled" -KeyValue $enablePublisherValidation.ToString().ToLowerInvariant() -WarningAction SilentlyContinue
            
            $importedPfxCertificate = Import-PfxCertificate -FilePath $pfxFile -Password $pfxPassword -CertStoreLocation Cert:\LocalMachine\My
            Write-Host "Keyvault Certificate Thumbprint: $($importedPfxCertificate.Thumbprint)"
            
            # Give SYSTEM permission to use the PFX file's private key
            $keyName = $importedPfxCertificate.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
            $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\$keyName"
            $acl = (Get-Item $keyPath).GetAccessControl('Access')
            $permission = 'NT AUTHORITY\SYSTEM',"Full","Allow"
            $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission
            $acl.AddAccessRule($accessRule)
            Set-Acl $keyPath $acl
            #$acl.Access
            
            Set-NavServerConfiguration -ServerInstance $serverInstance -KeyName AzureKeyVaultClientCertificateStoreLocation -KeyValue "LocalMachine" -WarningAction SilentlyContinue
            Set-NavServerConfiguration -ServerInstance $serverInstance -KeyName AzureKeyVaultClientCertificateStoreName     -KeyValue "My" -WarningAction SilentlyContinue
            Set-NavServerConfiguration -ServerInstance $serverInstance -KeyName AzureKeyVaultClientCertificateThumbprint    -KeyValue $importedPfxCertificate.Thumbprint -WarningAction SilentlyContinue
            Set-NavServerConfiguration -ServerInstance $serverInstance -KeyName AzureKeyVaultClientId                       -KeyValue $clientId -WarningAction SilentlyContinue
            
            if (!$doNotRestartServiceTier) {
                Write-Host "Restarting Service Tier"
                Set-NAVServerInstance -ServerInstance $serverInstance -Restart
                while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
                    Start-Sleep -Seconds 1
                }
            }
        } -argumentList (Get-BcContainerPath -containerName $containerName -path $sharedPfxFile), $pfxPassword, $clientId, $enablePublisherValidation, $doNotRestartServiceTier
    }
    finally {
        if ($removeSharedPfxFile -and (Test-Path $sharedPfxFile)) {
            Remove-Item -Path $sharedPfxFile -Force
        }
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Set-BcContainerKeyVaultAadAppAndCertificate
