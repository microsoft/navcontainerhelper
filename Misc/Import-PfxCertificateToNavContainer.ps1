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

    $containerPfxCertificatePath = Get-BcContainerPath -containerName $containerName -path $pfxCertificatePath
    $copied = $false
    if ("$containerPfxCertificatePath" -eq "") {
        $containerPfxCertificatePath = Join-Path "c:\run" ([System.IO.Path]::GetFileName($pfxCertificatePath))
        Copy-FileToBcContainer -containerName $containerName -localPath $pfxCertificatePath -containerPath $containerPfxCertificatePath
        $copied = $true
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($pfxCertificatePath, [SecureString]$pfxPassword, $CertificateStoreLocation, $copied)

        Import-PfxCertificate -FilePath $pfxCertificatePath -CertStoreLocation $CertificateStoreLocation -Password $pfxPassword | Out-Null
        if ($copied) {
            Remove-Item -Path $pfxCertificatePath -Force
        }
    } -ArgumentList $containerPfxCertificatePath, $pfxPassword, $CertificateStoreLocation, $copied
}
Set-Alias -Name Import-PfxCertificateToNavContainer -Value Import-PfxCertificateToBcContainer
Export-ModuleMember -Function Import-PfxCertificateToBcContainer -Alias Import-PfxCertificateToNavContainer
