<# 
 .Synopsis
  Create a Lets Encrypt Certificate for a free 90 days trusted certificate
 .Description
  This command installs the ACME Sharp PowerShell module and uses this to create a trusted certificate valid for 90 days.
  Note that if rate limits are exceeded, the script will fail.
 .Parameter ContactEMailForLetsEncrypt
  Specify an email address of the person accepting subscriber agreement for LetsEncrypt (https://letsencrypt.org/repository/) in order to use Lets Encrypt to generate a secure SSL certificate, which is valid for 3 months.
 .Parameter publicDnsName
  Public DNS Name (URL/CNAME record pointing to your VM).
 .Parameter certificatePfxFilename
  Filename for certificate .pfx file
 .Parameter certificatePfxPassword
  Password for certificate .pfx file
 .Parameter WebSiteRef
  Local web site to use for ACME Challenge (default is Default Web Site) 
 .Parameter dnsAlias
  DNS Alias is obsolete - you do not need to specify this
 .Example
  New-LetsEncryptCertificate -ContactEMailForLetsEncrypt "me@my.com" -publicDnsName "host.westeurope.cloudapp.azure.com" -certificatePfxFilename "c:\temp\cert.pfx" -certificatePfxPassword $securePassword
#>
function New-LetsEncryptCertificate {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $ContactEMailForLetsEncrypt,
        [Parameter(Mandatory=$true)]
        [string] $publicDnsName,
        [Parameter(Mandatory=$true)]
        [string] $certificatePfxFilename,
        [Parameter(Mandatory=$true)]
        [SecureString] $certificatePfxPassword,
        [Parameter(Mandatory=$false)]
        [string] $WebSiteRef = "Default Web Site",
        [Parameter(Mandatory=$false)]
        [string] $dnsAlias = "dnsAlias"
    )

    $stateDir = Join-Path $hostHelperFolder "acmeState"
    Write-Host "Importing ACME-PS module (need 1.1.0-beta or higher)"
    Import-Module ACME-PS

    Write-Host "Initializing ACME State"
    $state = New-ACMEState -Path $stateDir
    
    Write-Host "Registring Contact EMail address and accept Terms Of Service"
    Get-ACMEServiceDirectory $state -ServiceName "LetsEncrypt" -PassThru | Out-Null
    New-ACMENonce $state | Out-Null
    New-ACMEAccountKey $state -PassThru | Out-Null
    New-ACMEAccount $state -EmailAddresses $ContactEMailForLetsEncrypt -AcceptTOS | Out-Null

    Renew-LetsEncryptCertificate -publicDnsName $publicDnsName -certificatePfxFilename $certificatePfxFilename -certificatePfxPassword $certificatePfxPassword
}
Export-ModuleMember -Function New-LetsEncryptCertificate
