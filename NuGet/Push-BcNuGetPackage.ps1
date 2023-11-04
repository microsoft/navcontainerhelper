<# 
 .Synopsis
  POC PREVIEW: Push Business Central NuGet Package to NuGet Server
 .Description
  Push Business Central NuGet Package to NuGet Server
#>
Function Push-BcNuGetPackage {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $nuGetServerUrl,
        [Parameter(Mandatory=$true)]
        [string] $nuGetToken,
        [Parameter(Mandatory=$true)]
        [string] $bcNuGetPackage
    )

    $nuGetFeed = [NuGetFeed]::Create($nuGetServerUrl, $nuGetToken, @('*'))
    $nuGetFeed.PushPackage($bcNuGetPackage)
}
Export-ModuleMember -Function Push-BcNuGetPackage
