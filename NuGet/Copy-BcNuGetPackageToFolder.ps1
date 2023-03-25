<# 
 .Synopsis
  POC PREVIEW: Publish Business Central NuGet Package to container
 .Description
  Publish Business Central NuGet Package to container
#>
Function Copy-BcNuGetPackageToFolder {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $nuGetServerUrl = "https://api.nuget.org/v3/index.json",
        [Parameter(Mandatory=$true)]
        [string] $nuGetToken,
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [System.Version] $version = [System.Version]'0.0.0.0',
        [string] $appSymbolsFolder,
        [string] $copyInstalledAppsToFolder = ""
    )

    Write-Host "Looking for NuGet package $packageName version $version"
    $package = Get-BcNugetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version
    if ($package) {
        $manifest = [xml](Get-Content (Join-Path $package 'manifest.nuspec') -Encoding UTF8)
        $manifest.package.metadata.dependencies.GetEnumerator() | ForEach-Object {
            Copy-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $_.id  -version $_.version -appSymbolsFolder $appSymbolsFolder -copyInstalledAppsToFolder $copyInstalledAppsToFolder
        }
        $appFiles = (Get-Item -Path (Join-Path $package '*.app')).FullName
        $appFiles | ForEach-Object {
            Copy-Item $_ -Destination $appSymbolsFolder -Force
            if ($copyInstalledAppsToFolder) {
                Copy-Item $_ -Destination $copyInstalledAppsToFolder -Force
            }
        }
    }
}
Export-ModuleMember -Function Copy-BcNuGetPackageToFolder
