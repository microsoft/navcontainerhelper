<# 
 .Synopsis
  Get Labels for an image from the registry
 .Description
  Get the labels for an image from the registry without pulling the image
  This is also the best way to check whether a new version of an image is available
 .Parameter imageName
  Name of the image for which you want to get the labels
 .Parameter registryCredential
  Credentials for the registry if you are using a private registry (incl. bcinsider)
 .Example
  $created = (Get-BcContainerImageLabels -imageName myimage:mytag).created
#>
function Get-BcContainerImageLabels {
    Param (
        [string] $imageName,
        [PSCredential] $registryCredential
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $webclient = New-Object System.Net.WebClient

    if ($imageName.IndexOf("/") -lt 0) {
        try {
            return (docker inspect $imageName | ConvertFrom-Json).Config.Labels
        }
        catch {
            return
        }
    }

    $registry = $imageName.Split("/")[0]
    $repository = $imageName.Substring($registry.Length+1).Split(":")[0]
    $tag = $imageName.Split(":")[1]
    if ("$tag" -eq "") {
        $tag = "w1"
    }

    $authorization = ""

    if ("$registry" -eq "mcr.microsoft.com") {

        # public repository - no authorization needed

    } elseif ($registryCredential) {

        $credentials = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($registryCredential.UserName + ":" + [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($registryCredential.Password))))
        $authorization = "Basic $credentials"

    } elseif ("$registry" -eq "bcinsider.azurecr.io" -or "$registry" -eq "bcprivate.azurecr.io") {

        throw "$registry registry requires authorization. Please specify username and password for the registry in registryCredential."

    } else {

        $repository = "$registry/$repository"
        $registry = "registry.hub.docker.com"
        $token = ($webclient.DownloadString("https://auth.docker.io/token?scope=repository:${repository}:pull&service=registry.docker.io") | ConvertFrom-Json).token
        $authorization = "Bearer $token"

    }

    $webclient.Headers.Add('Accept', “application/vnd.docker.distribution.manifest.v1+json”)
    if ($authorization) {
        $webclient.Headers.Add("Authorization", $authorization )
    }

    try {
        (($webclient.DownloadString("https://$registry/v2/$repository/manifests/$tag") | ConvertFrom-Json).history[0].v1Compatibility | ConvertFrom-Json).container_config.Labels
    }
    catch {
    }
}
Set-Alias -Name Get-NavContainerImageLabels -Value Get-BcContainerImageLabels
Export-ModuleMember -Function Get-BcContainerImageLabels -Alias Get-NavContainerImageLabels
