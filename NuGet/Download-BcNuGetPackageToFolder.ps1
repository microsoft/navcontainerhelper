<# 
 .Synopsis
  Download Apps from Business Central NuGet Package to folder
 .Description
  Download Apps from Business Central NuGet Package to folder
 .PARAMETER nuGetServerUrl
  NuGet Server URL
  Default: https://api.nuget.org/v3/index.json
 .PARAMETER nuGetToken
  NuGet Token for authenticated access to the NuGet Server
  If not specified, the NuGet Server is accessed anonymously (and needs to support this)
 .PARAMETER packageName
  Package Name to search for.
  This can be the full name or a partial name with wildcards.
  If more than one package is found, matching the name, an error is thrown.
 .PARAMETER version
  Package Version, following the nuget versioning rules
  https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges
 .PARAMETER appSymbolsFolder
  Folder where the apps are copied to
 .PARAMETER copyInstalledAppsToFolder
  If specified, apps are also copied to this folder
 .PARAMETER installedPlatform
  Version of the installed platform
 .PARAMETER installedCountry
  Country of the installed application
 .PARAMETER installedApps
  List of installed apps
  Format is an array of PSCustomObjects with properties Name, Publisher, id and Version
 .PARAMETER downloadDependencies
  Specifies which dependencies to download
  Allowed values are:
    - all: Download all dependencies
    - own: Download only dependencies that has the same publisher as the package
    - allButMicrosoft: Download all dependencies except packages with publisher Microsoft
    - allButApplication: Download all dependencies except the Application and Platform packages (Microsoft.Application and Microsoft.Platform)
    - allButPlatform: Download all dependencies except the Platform package (Microsoft.Platform)
    - none: Do not download any dependencies
#>
Function Download-BcNuGetPackageToFolder {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $nuGetServerUrl = "",
        [Parameter(Mandatory=$false)]
        [string] $nuGetToken = "",
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [string] $version = '0.0.0.0',
        [Parameter(Mandatory=$true)]
        [string] $appSymbolsFolder,
        [Parameter(Mandatory=$false)]
        [string] $copyInstalledAppsToFolder = "",
        [Parameter(Mandatory=$false)]
        [System.Version] $installedPlatform,
        [Parameter(Mandatory=$false)]
        [string] $installedCountry,
        [Parameter(Mandatory=$false)]
        [PSCustomObject[]] $installedApps = @(),
        [ValidateSet('all','own','allButMicrosoft','allButApplication','allButPlatform','none')]
        [string] $downloadDependencies = 'allButApplication'
    )
    Write-Host "Determining installedApps"

    Write-Host "Looking for NuGet package $packageName version $version"
    $package = Get-BcNugetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version
    if ($package) {
        $nuspec = Get-Content (Join-Path $package '*.nuspec' -Resolve) -Encoding UTF8
        $appfile = Join-Path $package '*.app' -Resolve
        Write-Host "NUSPEC:"
        $nuspec | Out-Host
        $manifest = [xml]$nuspec
        $packageId = $manifest.package.metadata.id
        $packageVersion = $manifest.package.metadata.version
        $manifest.package.metadata.dependencies.GetEnumerator() | ForEach-Object {
            $dependencyVersion = $_.Version
            $dependencyId = $_.Id
            $downloadIt = $false
            if ($dependencyId -eq 'Microsoft.Platform') {
                # Dependency is to the platform
                if ($installedPlatform) {
                    if (!([NuGetFeed]::IsVersionIncludedInRange($installedPlatform, $dependencyVersion))) {
                        # The version installed ins't compatible with the NuGet package found
                        throw "NuGet package $packageId (version $packageVersion) requires platform $dependencyVersion. You cannot install it on version $installedPlatform"
                    }
                }
                else {
                    $downloadIt = ($downloadDependencies -eq 'all')
                }
            }
            elseif ($dependencyId -match '^(.*[^\.]\.)?Application(\..*[^\.])?$') {
                # Dependency is to the application
                $dependencyPublisher = $matches[1].TrimEnd('.')
                if ($matches.Count -gt 2) {
                    $dependencyCountry = $matches[2].TrimStart('.')
                }
                else {
                    $dependencyCountry = ''
                }
                $installedApp = $installedApps | Where-Object { $_ -and $_.Name -eq 'Application' }
                if ($installedApp) {
                    if (!([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $dependencyVersion))) {
                        throw "NuGet package $packageId (version $packageVersion) requires application $dependencyVersion. You cannot install it on version $($installedApp.Version)"
                    }
                    if ($dependencyCountry -and $installedCountry) {
                        if ($installedCountry -ne $dependencyCountry) {
                            Write-Host -ForegroundColor Red "::WARNING::NuGet package $packageId (version $packageVersion) requires application $dependencyVersion for country $dependencyCountry. You might not be able to install it on country $installedCountry"
                        }
                    }
                    if ($dependencyPublisher) {
                        if ($installedApp.Publisher -ne $dependencyPublisher) {
                            Write-Host -ForegroundColor Red "::WARNING::NuGet package $packageId (version $packageVersion) requires application $dependencyVersion from publisher $dependencyPublisher. The installed application app is from publisher $($installedApp.Publisher)"
                        }
                    }
                }
                else {
                    $downloadIt = ($downloadDependencies -eq 'all' -or $downloadDependencies -eq 'allButPlatform')
                }
            }
            else {
                $installedApp = $installedApps | Where-Object { $_ -and $dependencyId -like "*$($_.id)*" }
                if ($installedApp) {
                    # Dependency is already installed, check version number
                    if (!([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $dependencyVersion))) {
                        # The version installed ins't compatible with the NuGet package found
                        throw "Dependency $dependencyId is already installed with version $($installedApp.Version), which is not compatible with the version $dependencyVersion required by the NuGet package $packageId (version $packageVersion))"
                    }
                }
                elseif ($downloadDependencies -eq 'all' -or $downloadDependencies -eq 'none' -or $downloadDependencies -eq 'allButPlatform' -or $downloadDependencies -eq 'allButMicrosoft' -or $downloadDependencies -eq 'allButApplication') {
                    $downloadIt = ($downloadDependencies -ne 'none')
                }
                else {
                    # downloadDependencies is own or allButMicrosoft
                    # check publisher and name
                    if ($dependencyId -match '^(.*[^\.])\.(.*[^\.])\.("[0-9A-F]{8}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{12}")$') {
                        # Matches publisher.name.appId format
                        $dependencyPublisher = $matches[1]
                        $dependencyName = $matches[2]
                        $dependencyAppId = $matches[3]
                        if ($downloadDependencies -eq 'allButMicrosoft') {
                            $downloadIt = ($dependencyPublisher -ne 'Microsoft')
                        }
                        else {
                            $downloadIt = ($dependencyPublisher -eq $manifest.package.authors)
                        }
                    }
                    else {
                        # Could not match publisher.name.appId format
                        # All microsoft references should resolve - download it if we want allButMicrosoft
                        $downloadIt = ($downloadDependencies -eq 'allButMicrosoft')
                    }
                }
            }
            if ($downloadIt) {
                try {
                    Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $dependencyId -version $dependencyVersion -appSymbolsFolder $appSymbolsFolder -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedApps $installedApps
                }
                catch {
                    # If we cannot download the dependency, try downloading using the AppID
                    if ($dependencyId -match '^.*("[0-9A-F]{8}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{12}")$') {
                        # If dependencyId ends in a GUID (AppID) then try downloading using the 
                        Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $matches[1] -version $dependencyVersion -appSymbolsFolder $appSymbolsFolder -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedApps $installedApps
                    }
                    else {
                        throw
                    }
                }
            }
        }
        $appFiles = (Get-Item -Path (Join-Path $package '*.app')).FullName
        $appFiles | ForEach-Object {
            Copy-Item $_ -Destination $appSymbolsFolder -Force
            if ($copyInstalledAppsToFolder) {
                Copy-Item $_ -Destination $copyInstalledAppsToFolder -Force
            }
        }
        Remove-Item -Path $package -Recurse -Force
    }
}
Set-Alias -Name Copy-BcNuGetPackageToFolder -Value Download-BcNuGetPackageToFolder
Export-ModuleMember -Function Download-BcNuGetPackageToFolder -Alias Copy-BcNuGetPackageToFolder
