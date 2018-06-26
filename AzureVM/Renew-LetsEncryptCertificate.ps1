<# 
 .Synopsis
  Renew a Lets Encrypt Certificate for a renew free 90 days trusted certificate
 .Description
  This command uses the Lets Encrypt ACME powershell module to renew a trusted certificate valid for 90 days.
  Note that if rate limits are exceeded, the script will fail.
 .Parameter publicDnsName
  Public DNS Name (URL/CNAME record pointing to your VM).
 .Parameter CertPfxFilename
  Filename for certificate .pfx file
 .Parameter CertPfxPassword
  Password for certificate .pfx file
 .Example
  Renew-LetsEncryptCertificate -publicDnsName "host.westeurope.cloudapp.azure.com" -CertPfxFilename "c:\temp\cert.pfx" -CertPfxPassword "S0mep@ssw0rd!"
#>
function Renew-LetsEncryptCertificate {

    Param (
        [Parameter(Mandatory=$true)]
        [string]$publicDnsName,
        [Parameter(Mandatory=$true)]
        [string]$CertPfxFilename,
        [Parameter(Mandatory=$true)]
        [string]$CertPfxPassword,
        [Parameter(Mandatory=$false)]
        [string]$dnsAlias = "dnsAlias"
    )

    Import-Module ACMESharp

    Write-Host "Requesting certificate"
    $certAlias = "$publicDnsName-$(get-date -format yyyy-MM-dd--HH-mm)"
    Remove-Item -Path $certPfxFilename -Force -ErrorAction Ignore
    New-ACMECertificate -Generate -IdentifierRef $dnsAlias -Alias $certAlias
    Submit-ACMECertificate -CertificateRef $certAlias
    Update-ACMECertificate -CertificateRef $certAlias
    
    Write-Host "Downloading $certPfxFilename"
    Get-ACMECertificate -CertificateRef $certAlias -ExportPkcs12 $certPfxFilename -CertificatePassword $certPfxPassword

}
Export-ModuleMember -Function Renew-LetsEncryptCertificate
