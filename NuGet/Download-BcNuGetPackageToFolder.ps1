<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Download Apps from Business Central NuGet Package to folder
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
 .PARAMETER silent
  Suppress output
 .PARAMETER select
  Select the package to download if more than one package is found matching the name and version
  - Earliest: Select the earliest version
  - Latest: Select the latest version (default)
  - Exact: Select the exact version
  - Any: Select the first version found
 .PARAMETER folder
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
        [switch] $silent,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Earliest','Latest','Exact','Any')]
        [string] $select = 'Latest',
        [Parameter(Mandatory=$true)]
        [alias('appSymbolsFolder')]
        [string] $folder,
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

    function dump([string]$message) {
        if (!$silent) {
            Write-Host $message
        }
    }

    Write-Host "Looking for NuGet package $packageName version $version ($select match)"
    $package = Get-BcNugetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version -silent:$silent -select $select
    if ($package) {
        $nuspec = Get-Content (Join-Path $package '*.nuspec' -Resolve) -Encoding UTF8
        Dump "::group::NUSPEC"
        $nuspec | ForEach-Object { Dump $_ }
        Dump "::endgroup::"
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
            elseif ($dependencyId -match '^([^\.]+\.)?Application(\.[^\.]+)?$') {
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
                            Dump "::WARNING::NuGet package $packageId (version $packageVersion) requires application $dependencyVersion for country $dependencyCountry. You might not be able to install it on country $installedCountry"
                        }
                    }
                    if ($dependencyPublisher) {
                        if ($installedApp.Publisher -ne $dependencyPublisher) {
                            Dump "::WARNING::NuGet package $packageId (version $packageVersion) requires application $dependencyVersion from publisher $dependencyPublisher. The installed application app is from publisher $($installedApp.Publisher)"
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
                if ($dependencyId -match '^.*("[0-9A-F]{8}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{12}")$') {
                    # If dependencyId ends in a GUID (AppID) then use the AppId for downloading dependencies
                    Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $matches[1] -version $dependencyVersion -folder $folder -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedApps $installedApps -downloadDependencies $downloadDependencies -silent:$silent -select $select
                }
                else {
                    # AppId not specified, use the dependencyId as is
                    Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $dependencyId -version $dependencyVersion -folder $folder -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedApps $installedApps -downloadDependencies $downloadDependencies -silent:$silent -select $select
                }
            }
        }
        $appFiles = (Get-Item -Path (Join-Path $package '*.app')).FullName
        $appFiles | ForEach-Object {
            Copy-Item $_ -Destination $folder -Force
            if ($copyInstalledAppsToFolder) {
                Copy-Item $_ -Destination $copyInstalledAppsToFolder -Force
            }
        }
        Remove-Item -Path $package -Recurse -Force
    }
}
Set-Alias -Name Copy-BcNuGetPackageToFolder -Value Download-BcNuGetPackageToFolder
Export-ModuleMember -Function Download-BcNuGetPackageToFolder -Alias Copy-BcNuGetPackageToFolder
