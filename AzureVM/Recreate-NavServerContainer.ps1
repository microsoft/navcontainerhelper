<# 
 .Synopsis
  Replace navserver container with the same image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called navserver.
  Running this command will replace the container with a new container using the same image - recreateing or refreshing the container.
 .Parameter certificatePfxUrl
  Secure Url to certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter certificatePfxPassword
  Password for certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter publicDnsName
  Public Dns name (CNAME record) pointing to the host machine
 .Example
  Recreate-NavServerContainer
 .Example
  Recreate-NavServerContainer -certificatePfxUrl <secureurl> -certificatePfxPassword <password> -publicDnsName myhost.navdemo.net
#>
function Recreate-NavServerContainer {
    Param(
        [string]$certificatePfxUrl = "", 
        [string]$certificatePfxPassword = "", 
        [string]$publicDnsName = ""
    )

    $imageName = Get-NavContainerImageName -containerName navserver
    Replace-NavServerContainer -imageName $imageName -certificatePfxUrl $certificatePfxUrl -certificatePfxPassword $certificatePfxPassword -publicDnsName $publicDnsName
}
Export-ModuleMember -Function Recreate-NavServerContainer
