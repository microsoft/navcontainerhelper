<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Push Business Central NuGet Package to NuGet Server
 .Description
  Push Business Central NuGet Package to NuGet Server
 .PARAMETER nuGetServerUrl
  NuGet Server URL
 .PARAMETER nuGetToken
  NuGet Token for authenticated access to the NuGet Server
 .PARAMETER bcNuGetPackage
  Path to BcNuGetPackage to push. This is the value returned by New-BcNuGetPackage.
 .EXAMPLE
  $package = New-BcNuGetPackage -appfile $appFileName
  Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
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

    $nuGetFeed = [NuGetFeed]::Create($nuGetServerUrl, $nuGetToken, @(), @(), $bcContainerHelperConfig.NuGetSearchResultsCacheRetentionPeriod, $bcContainerHelperConfig.BcNuGetCacheFolder)

    $nuGetFeed.PushPackage($bcNuGetPackage)
}
Export-ModuleMember -Function Push-BcNuGetPackage
