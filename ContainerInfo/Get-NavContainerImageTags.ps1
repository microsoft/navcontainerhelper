<# 
 .Synopsis
  Get Image Tags available for an image from the registry
 .Description
  Get the tags available for an image from the registry without pulling images
 .Parameter imageName
  Name of the image for which you want to get the available tags
 .Parameter registryCredential
  Credentials for the registry if you are using a private registry (incl. bcinsider)
 .Parameter pageSize
  The function will always retrieve all tags, this parameter just specifies the page size used when querying tags. 0 means don't use paging. If registryCredential is set, the default pagesize is 1000 else the default is to not use paging.
 .Example
 (Get-BcContainerImageTags -imageName myimage:mytags).tags
#>
function Get-BcContainerImageTags {
    Param (
        [string] $imageName,
        [PSCredential] $registryCredential,
        [int] $pageSize = -1
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $webclient = New-Object System.Net.WebClient

    $registry = $imageName.Split("/")[0]
    $repository = $imageName.Substring($registry.Length+1).Split(":")[0]

    $authorization = ""

    if ("$registry" -eq "mcr.microsoft.com") {

        # public repository - no authorization needed

    } elseif ($registryCredential) {

        $credentials = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($registryCredential.UserName + ":" + [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($registryCredential.Password))))
        $authorization = "Basic $credentials"
        if ($pageSize -eq -1) {
            $pageSize = 1000
        }

    } elseif ("$registry" -eq "bcinsider.azurecr.io" -or "$registry" -eq "bcprivate.azurecr.io") {

        throw "$registry registry requires authorization. Please specify username and password for the registry in registryCredential."

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
        $url = "https://$registry/v2/$repository/tags/list"
        if ($pageSize -gt 0) {
            $sometags = ($webclient.DownloadString("${url}?n=$pageSize") | ConvertFrom-Json)
            $tags = $sometags
            while ($sometags.tags.Count -gt 0) {
                $sometags = ($webclient.DownloadString("${url}?n=$pageSize&last=$($sometags.tags[$sometags.tags.Count-1])") | ConvertFrom-Json)
                $tags.tags += $sometags.tags
            }
        } else {
            $tags = ($webclient.DownloadString("$url") | ConvertFrom-Json)
        }
        $tags
    }
    catch {
    }
}
Set-Alias -Name Get-NavContainerImageTags -Value Get-BcContainerImageTags
Export-ModuleMember -Function Get-BcContainerImageTags -Alias Get-NavContainerImageTags
