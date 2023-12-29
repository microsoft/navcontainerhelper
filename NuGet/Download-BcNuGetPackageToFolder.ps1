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
 .PARAMETER select
  Select the package to download if more than one package is found matching the name and version
  - Earliest: Select the earliest version
  - Latest: Select the latest version (default)
  - LatestMatching: Select the latest version matching the already installed dependencies
  - Exact: Select the exact version
  - Any: Select the first version found
 .PARAMETER folder
  Folder where the apps are copied to
 .PARAMETER copyInstalledAppsToFolder
  If specified, apps are also copied to this folder
 .PARAMETER installedPlatform
  Version of the installed platform
 .PARAMETER installedCountry
  Country of the installed application. installedCountry is used to determine if the NuGet package is compatible with the installed application localization
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
 .PARAMETER allowPrerelease
  Include prerelease versions in the search
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
        [Parameter(Mandatory=$false)]
        [ValidateSet('Earliest','Latest','LatestMatching','Exact','Any')]
        [string] $select = 'Latest',
        [Parameter(Mandatory=$true)]
        [alias('appSymbolsFolder')]
        [string] $folder,
        [Parameter(Mandatory=$false)]
        [string] $copyInstalledAppsToFolder = "",
        [Parameter(Mandatory=$false)]
        [System.Version] $installedPlatform,
        [Parameter(Mandatory=$false)]
        [string] $installedCountry = '',
        [Parameter(Mandatory=$false)]
        [PSCustomObject[]] $installedApps = @(),
        [ValidateSet('all','own','allButMicrosoft','allButApplication','allButPlatform','none')]
        [string] $downloadDependencies = 'allButApplication',
        [switch] $allowPrerelease
    )

    $returnValue = $false
    $findSelect = $select
    if ($select -eq 'LatestMatching') {
        $findSelect = 'Latest'
    }
    $excludeVersions = @()
    Write-Host "Looking for NuGet package $packageName version $version ($select match)"
    while ($true) {
        $feed, $packageId, $packageVersion = Find-BcNugetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version -excludeVersions $excludeVersions -verbose:($VerbosePreference -eq 'Continue') -select $findSelect -allowPrerelease:($allowPrerelease.IsPresent)
        if (-not $feed) {
            Write-Host "No package found matching package name $($packageName) Version $($version)"
            break
        }
        else {
            Write-Host "Best match for package name $($packageName) Version $($version): $packageId Version $packageVersion from $($feed.Url)"
            $package = $feed.DownloadPackage($packageId, $packageVersion)
            $nuspec = Get-Content (Join-Path $package '*.nuspec' -Resolve) -Encoding UTF8
            Write-Verbose "NUSPEC:"
            $nuspec | ForEach-Object { Write-Verbose $_ }
            $manifest = [xml]$nuspec
            $dependenciesErr = ''
            foreach($dependency in $manifest.package.metadata.dependencies.GetEnumerator()) {
                $dependencyVersion = $dependency.Version
                $dependencyId = $dependency.Id
                $dependencyCountry = ''
                $downloadIt = $false
                if ($dependencyId -eq 'Microsoft.Platform') {
                    $dependencyPublisher = 'Microsoft'
                    # Dependency is to the platform
                    if ($installedPlatform) {
                        if (!([NuGetFeed]::IsVersionIncludedInRange($installedPlatform, $dependencyVersion))) {
                            # The NuGet package found isn't compatible with the installed platform
                            $dependenciesErr = "NuGet package $packageId (version $packageVersion) requires platform $dependencyVersion. You cannot install it on version $installedPlatform"
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
                    if ($installedCountry -and $dependencyCountry -and ($installedCountry -ne $dependencyCountry)) {
                        # The NuGet package found isn't compatible with the installed application
                        Write-Host "WARNING: NuGet package $packageId (version $packageVersion) requires $dependencyCountry application. You have $installedCountry application installed"
                    }                   
                    $installedApp = $installedApps | Where-Object { $_ -and $_.Name -eq 'Application' }
                    if ($installedApp) {
                        if (!([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $dependencyVersion))) {
                            $dependenciesErr = "NuGet package $packageId (version $packageVersion) requires application $dependencyVersion. You cannot install it on version $($installedApp.Version)"
                        }
                    }
                    else {
                        $downloadIt = ($downloadDependencies -eq 'all' -or $downloadDependencies -eq 'allButPlatform')
                    }
                }
                else {
                    $dependencyPublisher = ''
                    if ($dependencyId -match '^([^\.]+)\.([^\.]+)\.([^\.]+\.)?([0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12})$') {
                        # Matches publisher.name.[country.].appId format (country section is only for microsoft apps)
                        $dependencyPublisher = $matches[1]
                        if ($dependencyPublisher -eq 'microsoft' -and $matches.Count -gt 3) {
                            $dependencyCountry = $matches[3].TrimEnd('.')
                        }
                    }
                    $installedApp = $installedApps | Where-Object { $_ -and $_.id -and $dependencyId -like "*$($_.id)*" }
                    if ($installedApp) {
                        # Dependency is already installed, check version number
                        if (!([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $dependencyVersion))) {
                            # The version installed ins't compatible with the NuGet package found
                            $dependenciesErr = "Dependency $dependencyId is already installed with version $($installedApp.Version), which is not compatible with the version $dependencyVersion required by the NuGet package $packageId (version $packageVersion))"
                        }
                    }
                    elseif ($downloadDependencies -eq 'own') {
                        $downloadIt = ($dependencyPublisher -eq $manifest.package.authors)
                    }
                    elseif ($downloadDependencies -eq 'allButMicrosoft') {
                        # Download if publisher isn't Microsoft (including if publisher is empty)
                        $downloadIt = ($dependencyPublisher -ne 'Microsoft')
                    }
                    else {
                        $downloadIt = ($downloadDependencies -ne 'none')
                    }
                }
                if ($dependenciesErr) {
                    if ($select -ne 'LatestMatching') {
                        throw $dependenciesErr
                    }
                    else {
                        # If we are looking for the latest matching version, then we can try to find another version
                        Write-Host "WARNING: $dependenciesErr"
                        break
                    }
                }
                if ($downloadIt) {
                    $checkPackageName = ''
                    if ($dependencyId -match '^.*([0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12})$') {
                        # If dependencyId ends in a GUID (AppID) then use the AppId for downloading dependencies
                        $dependencyId = $matches[1]
                        if ($dependencyCountry) {
                            # Dependency is to a specific country version - must find the country version of the dependency
                            $dependencyId = "$dependencyCountry.$dependencyId"
                        }
                        elseif ($installedCountry -and $dependencyPublisher -eq 'Microsoft') {
                            # Looking for a Microsoft package - check if it exists for the installed country (revert to appId if not)
                            $checkPackageName = "$installedCountry.$dependencyId"
                        }    
                    }
                    elseif (($dependencyId -match '^Microsoft.Application(\.[^\.]+)?$') -and ($matches.Count -eq 1)) {
                        # If dependency is to the Application without a specific country, then check if a localization version of the application exists for the installed country
                        $checkPackageName = "Microsoft.Application.$installedCountry"
                    }
                    if ($checkPackageName) {
                        Write-Host -ForegroundColor Yellow $checkPackageName
                        if (Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $checkPackageName -version $dependencyVersion -folder $package -installedApps $installedApps -downloadDependencies $downloadDependencies -verbose:($VerbosePreference -eq 'Continue') -select $select) {
                            $returnValue = $true
                            $downloadIt = $false
                        }
                    }
                    if ($downloadIt) {
                        Write-Host -ForegroundColor Yellow $dependencyId
                        if (Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $dependencyId -version $dependencyVersion -folder $package -installedApps $installedApps -downloadDependencies $downloadDependencies -verbose:($VerbosePreference -eq 'Continue') -select $select) {
                            $returnValue = $true
                        }
                    }
                }
            }
            if ($dependenciesErr) {
                # If we are looking for the latest matching version, then we can try to find another version
                $excludeVersions += $packageVersion
                Remove-Item -Path $package -Recurse -Force
                continue
            }
            if (Test-Path (Join-Path $package $installedCountry) -PathType Container) {
                # NuGet packages of Runtime packages might exist in different versions for different countries
                # The runtime package might contain C# invoke calls with different methodis for different countries
                # if the installedCountry doesn't have a special version, then the w1 version is used (= empty string)
                # If the package contains a country specific folder, then use that
                $appFiles = Get-Item -Path (Join-Path $package "$installedCountry/*.app")
            }
            else {
                $appFiles = Get-Item -Path (Join-Path $package "*.app")
            }
            foreach($appFile in $appFiles) {
                $returnValue = $true
                Copy-Item $appFile.FullName -Destination $folder -Force
                if ($copyInstalledAppsToFolder) {
                    Copy-Item $appFile.FullName -Destination $copyInstalledAppsToFolder -Force
                }
            }
            Remove-Item -Path $package -Recurse -Force
            break
        }
    }
    return $returnValue
}
Set-Alias -Name Copy-BcNuGetPackageToFolder -Value Download-BcNuGetPackageToFolder
Export-ModuleMember -Function Download-BcNuGetPackageToFolder -Alias Copy-BcNuGetPackageToFolder
