<# 
 .Synopsis
  Get Image Tags available for an image from the registry
 .Description
  Get the tags available for an image from the registry without pulling images
 .Parameter imageName
  Name of the image for which you want to get the available tags
 .Parameter registryCredential
  Credentials for the registry if you are using a private registry (incl. bcinsider)
 .Example
 (Get-NavContainerImageTags -imageName "mcr.microsoft.com/businesscentral/onprem").tags
#>
function Get-NavContainerImageTags {
    Param(
        [string] $imageName,
        [PSCredential] $registryCredential
    )

    $webclient = New-Object System.Net.WebClient

    $registry = $imageName.Split("/")[0]
    $repository = $imageName.Substring($registry.Length+1).Split(":")[0]

    $authorization = ""

    if ("$registry" -eq "mcr.microsoft.com") {

        # public repository - no authorization needed

    } elseif ($registryCredential) {

        $credentials = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($registryCredential.UserName + ":" + [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($registryCredential.Password))))
        $authorization = "Basic $credentials"

    } elseif ("$registry" -eq "bcinsider.azurecr.io") {

        throw "bcinsider.azurecr.io registry requires authorization. Please specify username and password for the registry in registryCredential."

    } else {

        $repository = "$registry/$repository"
        $registry = "registry.hub.docker.com"
        $token = ($webclient.DownloadString("https://auth.docker.io/token?scope=repository:${repository}:pull&service=registry.docker.io") | ConvertFrom-Json).token
        $authorization = "Bearer $token"

    }

    $webclient.Headers.Add('Accept', “application/json”)
    if ($authorization) {
        $webclient.Headers.Add("Authorization", $authorization )
    }

    try {
        ($webclient.DownloadString("https://$registry/v2/$repository/tags/list") | ConvertFrom-Json)
    }
    catch {
    }

}
Export-ModuleMember -Function Get-NavContainerImageTags
