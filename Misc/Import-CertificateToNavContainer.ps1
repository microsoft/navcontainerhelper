<# 
 .Synopsis
  Import a Certificate in a Container
 .Description
  Import a Certificate to the certificate store in a container
 .Parameter ContainerName
  Name of the container in which you want to import the certificate
 .Parameter CertificatePath
  Location of the Certificate. If this location is not shared with the container, the certificate will be copied to the container and then imported
 .Parameter CertificateStoreLocation
  Location in the certificate store, where the certificate will be imported
 .Example
  Import-CertificateToBcContainer -containerName test -certificatePath 'c:\temp\cert.cer' -CertificateStoreLocation 'cert:\localmachine\my'
#>
function Import-CertificateToBcContainer {
   Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$true)]
        [string] $certificatePath,
        [String] $CertificateStoreLocation = "cert:\localmachine\my"
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Write-Host "Importing certificate $([System.IO.Path]::GetFileName($certificatePath.Split('?')[0]))"

    $copied = $false
    if ($certificatePath -like "http://*" -or $certificatePath -like "https://*") {
        $containerCertificatePath = $certificatePath
    } else {
        $containerCertificatePath = Get-BcContainerPath -containerName $containerName -path $certificatePath
        if ("$containerCertificatePath" -eq "") {
            $containerCertificatePath = Join-Path "c:\run" "$([Guid]::NewGuid().ToString()).cer"
            Copy-FileToBcContainer -containerName $containerName -localPath $certificatePath -containerPath $containerCertificatePath
            $copied = $true
        }
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($certificatePath, $certificateStoreLocation, $copied)

        if ($certificatePath -like "http://*" -or $certificatePath -like "https://*") {
            $cerUrl = $certificatePath
            $certificatePath = Join-Path "c:\run" "$([Guid]::NewGuid().ToString()).cer"
            DownloadFileLow -sourceUrl $cerUrl -destinationFile $certificatePath
            $copied = $true
        }

        Import-Certificate -FilePath $certificatePath -CertStoreLocation $CertificateStoreLocation | Out-Null
        if ($copied) {
            Remove-Item -Path $certificatePath -Force
        }
    } -ArgumentList $containerCertificatePath, $CertificateStoreLocation, $copied

    Write-Host -ForegroundColor Green "Certificate $([System.IO.Path]::GetFileName($certificatePath.Split('?')[0])) successfully imported"
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Import-CertificateToBcContainer
