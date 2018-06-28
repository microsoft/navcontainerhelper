<# 
 .Synopsis
  Renew a Lets Encrypt Certificate for a renew free 90 days trusted certificate
 .Description
  This command uses the Lets Encrypt ACME powershell module to renew a trusted certificate valid for 90 days.
  Note that if rate limits are exceeded, the script will fail.
 .Parameter publicDnsName
  Public DNS Name (URL/CNAME record pointing to your VM).
 .Parameter certificatePfxFilename
  Filename for certificate .pfx file
 .Parameter certificatePfxPassword
  Password for certificate .pfx file
 .Example
  Renew-LetsEncryptCertificate -publicDnsName "host.westeurope.cloudapp.azure.com" -certificatePfxFilename "c:\temp\cert.pfx" -certificatePfxPassword (ConvertTo-SecureString -String "S0mep@ssw0rd!" -AsPlainText -Force)
#>
function Renew-LetsEncryptCertificate {

    Param (
        [Parameter(Mandatory=$true)]
        [string]$publicDnsName,
        [Parameter(Mandatory=$true)]
        [string]$certificatePfxFilename,
        [Parameter(Mandatory=$true)]
        [SecureString]$certificatePfxPassword,
        [Parameter(Mandatory=$false)]
        [string]$dnsAlias = "dnsAlias"
    )

    Import-Module ACMESharp

    Write-Host "Requesting certificate"
    $certAlias = "$publicDnsName-$(get-date -format yyyy-MM-dd--HH-mm)"
    Remove-Item -Path $certificatePfxFilename -Force -ErrorAction Ignore
    New-ACMECertificate -Generate -IdentifierRef $dnsAlias -Alias $certAlias
    Submit-ACMECertificate -CertificateRef $certAlias
    Update-ACMECertificate -CertificateRef $certAlias
    
    Write-Host "Downloading $certificatePfxFilename"
    Get-ACMECertificate -CertificateRef $certAlias -ExportPkcs12 $certificatePfxFilename -CertificatePassword ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($certificatePfxPassword)))
}
Export-ModuleMember -Function Renew-LetsEncryptCertificate
