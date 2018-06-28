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
 .Example
  New-LetsEncryptCertificate -ContactEMailForLetsEncrypt "me@my.com" -publicDnsName "host.westeurope.cloudapp.azure.com" -certificatePfxFilename "c:\temp\cert.pfx" -certificatePfxPassword $securePassword
#>
function New-LetsEncryptCertificate {

    Param (
        [Parameter(Mandatory=$true)]
        [string]$ContactEMailForLetsEncrypt,
        [Parameter(Mandatory=$true)]
        [string]$publicDnsName,
        [Parameter(Mandatory=$true)]
        [string]$certificatePfxFilename,
        [Parameter(Mandatory=$true)]
        [SecureString]$certificatePfxPassword,
        [Parameter(Mandatory=$false)]
        [string]$WebSiteRef = "Default Web Site",
        [Parameter(Mandatory=$false)]
        [string]$dnsAlias = "dnsAlias"
    )

    Write-Host "Installing ACMESharp PowerShell modules"
    Install-Module -Name ACMESharp -AllowClobber -force -ErrorAction SilentlyContinue
    Install-Module -Name ACMESharp.Providers.IIS -force -ErrorAction SilentlyContinue
    Import-Module ACMESharp
    Enable-ACMEExtensionModule -ModuleName ACMESharp.Providers.IIS -ErrorAction SilentlyContinue
    
    Write-Host "Initializing ACMEVault"
    Initialize-ACMEVault
    
    Write-Host "Register Contact EMail address and accept Terms Of Service"
    New-ACMERegistration -Contacts "mailto:$ContactEMailForLetsEncrypt" -AcceptTos
    
    Write-Host "Creating new dns Identifier"
    New-ACMEIdentifier -Dns $publicDnsName -Alias $dnsAlias

    Write-Host "Performing Lets Encrypt challenge to $WebSiteRef"
    Complete-ACMEChallenge -IdentifierRef $dnsAlias -ChallengeType http-01 -Handler iis -HandlerParameters @{ WebSiteRef = $webSiteRef }
    Submit-ACMEChallenge -IdentifierRef $dnsAlias -ChallengeType http-01
    sleep -s 60
    Update-ACMEIdentifier -IdentifierRef $dnsAlias
    
    Renew-LetsEncryptCertificate -publicDnsName $publicDnsName -certificatePfxFilename $certificatePfxFilename -certificatePfxPassword $certificatePfxPassword -dnsAlias $dnsAlias
}
Export-ModuleMember -Function New-LetsEncryptCertificate

