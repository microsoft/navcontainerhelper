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
 .Parameter dnsAlias
  DNS Alias is obsolete - you do not need to specify this
 .Example
  Renew-LetsEncryptCertificate -publicDnsName "host.westeurope.cloudapp.azure.com" -certificatePfxFilename "c:\temp\cert.pfx" -certificatePfxPassword (ConvertTo-SecureString -String "S0mep@ssw0rd!" -AsPlainText -Force)
#>
function Renew-LetsEncryptCertificate {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $publicDnsName,
        [Parameter(Mandatory=$true)]
        [string] $certificatePfxFilename,
        [Parameter(Mandatory=$true)]
        [SecureString] $certificatePfxPassword,
        [Parameter(Mandatory=$false)]
        [string] $dnsAlias = "dnsAlias"
    )

    Write-Host "Importing ACME-PS module (need 1.1.0-beta or higher)"
    Import-Module ACME-PS

    $stateDir = Join-Path $hostHelperFolder "acmeState"
    if (Test-Path $certificatePfxFilename) {
        Write-Host "Removing existing certificate"
        Remove-Item -Path $certificatePfxFilename -Force
    }

    Write-Host "Creating new dns Identifier"
    $state = Get-ACMEState -Path $stateDir
    New-ACMENonce $state -PassThru | Out-Null
    $identifier = New-ACMEIdentifier $publicDnsName

    Write-Host "Creating ACME Order"
    $order = New-ACMEOrder $state -Identifiers $identifier

    Write-Host "Getting ACME Authorization"
    $authZ = Get-ACMEAuthorization -State $state -Order $order

    Write-Host "Getting ACME Challenge"
    $challenge = Get-ACMEChallenge $state $authZ "http-01"

    # Create the file requested by the challenge
    $fileName = "C:\inetpub\wwwroot$($challenge.Data.RelativeUrl)"
    $challengePath = [System.IO.Path]::GetDirectoryName($filename);
    if(-not (Test-Path $challengePath)) {
        New-Item -Path $challengePath -ItemType Directory | Out-Null
    }

    Set-Content -Path $fileName -Value $challenge.Data.Content -NoNewLine

    # Check if the challenge is readable
    Invoke-WebRequest $challenge.Data.AbsoluteUrl -UseBasicParsing | Out-Null

    Write-Host "Completing ACME Challenge"
    # Signal the ACME server that the challenge is ready
    $challenge | Complete-ACMEChallenge $state | Out-Null

    # Wait a little bit and update the order, until we see the states
    while($order.Status -notin ("ready","invalid")) {
        Start-Sleep -Seconds 10
        $order | Update-ACMEOrder $state -PassThru | Out-Null
    }

    $certKeyFile = "$stateDir\$publicDnsName-$(get-date -format yyyy-MM-dd-HH-mm-ss).key.xml"
    $certKey = New-ACMECertificateKey -path $certKeyFile

    Write-Host "Completing ACME Order"
    Complete-ACMEOrder $state -Order $order -CertificateKey $certKey | Out-Null

    # Now we wait until the ACME service provides the certificate url
    while(-not $order.CertificateUrl) {
        Start-Sleep -Seconds 15
        $order | Update-Order $state -PassThru | Out-Null
    }

    # As soon as the url shows up we can create the PFX
    Write-Host "Exporting certificate to $certificatePfxFilename"
    Export-ACMECertificate $state -Order $order -CertificateKey $certKey -Path $certificatePfxFilename -Password $certificatePfxPassword
}
Export-ModuleMember -Function Renew-LetsEncryptCertificate
