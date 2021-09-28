<# 
 .Synopsis
  Import a Pfx Certificate in a Container
 .Description
  Import a Pfx Certificate to the certificate store in a container
 .Parameter ContainerName
  Name of the container in which you want to import the certificate
 .Parameter pfxCertificatePath
  Location of the PfxCertificate. If this location is not shared with the container, the certificate will be copied to the container and then imported
 .Parameter pfxPassword
  The Secure Password for the Pfx Certificate
 .Parameter CertificateStoreLocation
  Location in the certificate store, where the certificate will be imported
 .Example
  Import-PfxCertificateToBcContainer -containerName test -pfxCertificatePath 'c:\temp\cert.pfx' -pfxPassword $pfxPassword -CertificateStoreLocation 'cert:\localmachine\my'
#>
function Import-PfxCertificateToBcContainer {
   Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$true)]
        [string] $pfxCertificatePath,
        [Parameter(Mandatory=$true)]
        [SecureString] $pfxPassword,
        [String] $CertificateStoreLocation = "cert:\localmachine\my"
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Write-Host "Importing certificate $([System.IO.Path]::GetFileName($pfxCertificatePath.Split('?')[0]))"

    $copied = $false
    if ($pfxCertificatePath -like "http://*" -or $pfxCertificatePath -like "https://*") {
        $containerPfxCertificatePath = $pfxCertificatePath
    } else {
        $containerPfxCertificatePath = Get-BcContainerPath -containerName $containerName -path $pfxCertificatePath
        if ("$containerPfxCertificatePath" -eq "") {
            $containerPfxCertificatePath = Join-Path "c:\run" "$([Guid]::NewGuid().ToString()).pfx"
            Copy-FileToBcContainer -containerName $containerName -localPath $pfxCertificatePath -containerPath $containerPfxCertificatePath
            $copied = $true
        }
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($pfxCertificatePath, [SecureString]$pfxPassword, $CertificateStoreLocation, $copied)

        if ($pfxCertificatePath -like "http://*" -or $pfxCertificatePath -like "https://*") {
            $pfxUrl = $pfxCertificatePath
            $pfxCertificatePath = Join-Path "c:\run" "$([Guid]::NewGuid().ToString()).pfx"
            (New-Object System.Net.WebClient).DownloadFile($pfxUrl, $pfxCertificatePath)
            $copied = $true
        }

        Import-PfxCertificate -FilePath $pfxCertificatePath -CertStoreLocation $CertificateStoreLocation -Password $pfxPassword | Out-Null
        Write-Host
        if ($copied) {
            Remove-Item -Path $pfxCertificatePath -Force
        }
    } -ArgumentList $containerPfxCertificatePath, $pfxPassword, $CertificateStoreLocation, $copied

    Write-Host -ForegroundColor Green "Certificate $([System.IO.Path]::GetFileName($pfxCertificatePath.Split('?')[0])) successfully imported"
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Import-PfxCertificateToNavContainer -Value Import-PfxCertificateToBcContainer
Export-ModuleMember -Function Import-PfxCertificateToBcContainer -Alias Import-PfxCertificateToNavContainer
