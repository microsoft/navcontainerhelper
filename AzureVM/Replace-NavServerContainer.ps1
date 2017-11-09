<# 
 .Synopsis
  Replace navserver container with a different image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called navserver.
  Running this command will replace the container with a new container with a different (or the same) image.
 .Parameter imageName
  imageName you want to use to replace the navserver container
 .Parameter certificatePfxUrl
  Secure Url to certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter certificatePfxPassword
  Password for certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter publicDnsName
  Public Dns name (CNAME record) pointing to the host machine
 .Example
  Replace-NavServerContainer -imageName navdocker.azurecr.io/dynamics-nav:devpreview-september-finus
 .Example
  Replace-NavServerContainer -imageName navdocker.azurecr.io/dynamics-nav:devpreview-september-fingb -certificatePfxUrl <secureurl> -certificatePfxPassword <password> -publicDnsName myhost.navdemo.net
#>
function Replace-NavServerContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName, 
        [string]$certificatePfxUrl = "", 
        [string]$certificatePfxPassword = "", 
        [string]$publicDnsName = ""
    )

    $SetupNavContainerScript = "c:\demo\SetupNavContainer.ps1"
    $setupDesktopScript = "c:\demo\SetupDesktop.ps1"

    if (!((Test-Path $SetupNavContainerScript) -and (Test-Path $setupDesktopScript))) {
        throw "The Replace-NavServerContainer is designed to work inside the Nav on Azure DEMO VMs"
    }

    $newImageName = $imageName
    $newCertificatePfxUrl = $certificatePfxUrl
    $newCertificatePfxPassword = $certificatePfxPassword
    $newPublicDnsName = $publicDnsName

    . C:\DEMO\Settings.ps1

    if ($newCertificatePfxUrl -ne "" -and $newCertificatePfxPassword -ne "" -and $newPublicDnsName -ne "") {
        Download-File -sourceUrl $newCertificatePfxUrl -destinationFile "c:\demo\certificate.pfx"
    
        ('$certificatePfxPassword = "'+$newCertificatePfxPassword+'"
        $certificatePfxFile = "c:\demo\certificate.pfx"
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePfxFile, $certificatePfxPassword)
        $certificateThumbprint = $cert.Thumbprint
        Write-Host "Certificate File Thumbprint $certificateThumbprint"
        if (!(Get-Item Cert:\LocalMachine\my\$certificateThumbprint -ErrorAction SilentlyContinue)) {
            Write-Host "Import Certificate to LocalMachine\my"
            Import-PfxCertificate -FilePath $certificatePfxFile -CertStoreLocation cert:\localMachine\my -Password (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force) | Out-Null
        }
        $dnsidentity = $cert.GetNameInfo("SimpleName",$false)
        if ($dnsidentity.StartsWith("*")) {
            $dnsidentity = $dnsidentity.Substring($dnsidentity.IndexOf(".")+1)
        }
        Remove-Item $certificatePfxFile -force
        Remove-Item "c:\run\my\SetupCertificate.ps1" -force
        ') | Add-Content "c:\myfolder\SetupCertificate.ps1"
    } else {
        # Self signed cert. - use hostname as publicDnsName
        $newPublicDnsName = $hostname
    }

    $imageId = docker images -q $newImageName
    if (!($imageId)) {
        Write-Host "pulling $newImageName"
        docker pull $newImageName
    }
    $country = Get-NavContainerCountry -containerOrImageName $newImageName

    if (Test-NavContainer -containerName navserver) {
        Write-Host "Remove container navserver"
        Remove-NavContainerSession -containerName $containerName
        $containerId = Get-NavContainerId -containerName $containerName
        docker rm $containerId -f | Out-Null
    }
    
    $settingsScript = "c:\demo\settings.ps1"
    $settings = Get-Content -Path  $settingsScript
    0..($settings.Count-1) | % { if ($settings[$_].StartsWith('$navDockerImage = ', "OrdinalIgnoreCase")) { $settings[$_] = ('$navDockerImage = "'+$newImageName + '"') } }
    Set-Content -Path $settingsScript -Value $settings

    Write-Host -ForegroundColor Green "Setup new Nav container"
    . $SetupNavContainerScript
    . $setupDesktopScript
}
Export-ModuleMember -Function Replace-NavServerContainer
