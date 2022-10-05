<# 
 .Synopsis
  POC PREVIEW: Publish Business Central NuGet Package to container
 .Description
  Publish Business Central NuGet Package to container
#>
Function Publish-BcNuGetPackageToContainer {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $nuGetServerUrl = "https://api.nuget.org/v3/index.json",
        [Parameter(Mandatory=$true)]
        [string] $nuGetToken,
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [System.Version] $version = [System.Version]'0.0.0.0',
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [switch] $skipVerification
    )

    $package = Get-BcNugetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version
    $manifest = [xml](Get-Content (Join-Path $package 'manifest.nuspec') -Encoding UTF8)
    $manifest.package.metadata.dependencies.GetEnumerator() | ForEach-Object {
        Publish-BcNuGetPackageToContainer -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $_.id  -version $_.version -containerName $containerName -tenant $tenant -skipVerification:$skipVerification
    }
    $appFiles = (Get-Item -Path (Join-Path $package '*.app')).FullName
    Publish-BcContainerApp -containerName $containerName -tenant $tenant -appFile $appFiles -sync -install -upgrade -checkAlreadyInstalled -skipVerification
}
Export-ModuleMember -Function Publish-BcNuGetPackageToContainer
