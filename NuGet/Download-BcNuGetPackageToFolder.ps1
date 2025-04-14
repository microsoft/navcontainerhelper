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
  - EarliestMatching: Select the earliest version matching the already installed dependencies
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
        [ValidateSet('Earliest','EarliestMatching','Latest','LatestMatching','Exact','Any')]
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
        [switch] $allowPrerelease,
        [switch] $checkLocalVersion
    )

try {
    $findSelect = $select
    if ($select -eq 'LatestMatching') {
        $findSelect = 'Latest'
    }
    if ($select -eq 'EarliestMatching') {
        $findSelect = 'Earliest'
    }
    $excludeVersions = @()
    if ($checkLocalVersion) {
        # Format Publisher.Name[.Country][.symbols][.AppId]
        if ($packageName -match '^(Microsoft)\.([^\.]+)(\.[^\.][^\.])?(\.symbols)?(\.[0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12})?$') {
            $publisher = $matches[1]
            $name = $matches[2]
            $countryPart = "$($matches[3])"
            $symbolsPart = "$($matches[4])"
            $appIdPart = "$($matches[5])"
            $checkPackageName = ''
            if ($name -ne 'Platform' -and $countryPart -eq '' -and $installedCountry -ne '') {
                $countryPart = ".$installedCountry"
                $checkPackageName = "$publisher.$name$countryPart$symbolsPart$appIdPart"
            }
            if ($checkPackageName -and $checkPackageName -ne $packageName) {
                $downloadedPackages = Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $checkPackageName -version $version -folder $folder -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedPlatform $installedPlatform -installedCountry $installedCountry -installedApps $installedApps -downloadDependencies $downloadDependencies -verbose:($VerbosePreference -eq 'Continue') -select $select -allowPrerelease:$allowPrerelease
                if ($downloadedPackages) {
                    return $downloadedPackages
                }
            }
            return Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version -folder $folder -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedPlatform $installedPlatform -installedCountry $installedCountry -installedApps $installedApps -downloadDependencies $downloadDependencies -verbose:($VerbosePreference -eq 'Continue') -select $select -allowPrerelease:$allowPrerelease
        }
    }
    Write-Host "Looking for NuGet package $packageName version $version ($select match)"
    if ($packageName -match '^Microsoft\.Platform(\.symbols)?$') {
        if ($installedPlatform) {
            $existingPlatform = $installedPlatform
        }
        else {
            $existingPlatform = $installedApps | Where-Object { $_ -and $_.Name -eq 'Platform' } | Select-Object -ExpandProperty Version
        }
        if ($existingPlatform -and ([NuGetFeed]::IsVersionIncludedInRange($existingPlatform, $version))) {
            Write-Host "Microsoft.Platform version $existingPlatform is already available"
            return @()
        }
    }
    elseif ($packageName -match '^([^\.]+\.)?Application(\.[^\.]+)?(\.symbols)?$') {
        $installedApp = $installedApps | Where-Object { $_ -and $_.Name -eq 'Application' }
        if ($installedApp -and ([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $version))) {
            Write-Host "Application version $($installedApp.Version) is already available"
            return @()
        }
    }
    elseif ($packageName -match '^([^\.]+)\.([^\.]+)(\.[^\.][^\.])?(\.symbols)?(\.[0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12})?$') {
        $installedApp = $installedApps | Where-Object { $_ -and $_.id -and $packageName -like "*$($_.id)*" }
        if ($installedApp -and ([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $version))) {
            Write-Host "$($installedApp.Name) from $($installedApp.publisher) version $($installedApp.Version) is already available (AppId=$($installedApp.id))"
            return @()
        }
    }
    while ($true) {
        $returnValue = @()
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
            $appId = ''
            if ($manifest.package.metadata.PSObject.Properties.Name -eq 'title') {
                $appName = $manifest.package.metadata.title
            }
            elseif ($manifest.package.metadata.PSObject.Properties.Name -eq 'description') {
                $appName = $manifest.package.metadata.description
            }
            else {
                $appName = $manifest.package.metadata.id
            }
            if ($manifest.package.metadata.id -match '^.*([0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12})$') {
                # If packageId ends in a GUID (AppID) then use the AppId for the packageId
                $appId = "$($matches[1])"
            }
            elseif ($manifest.package.metadata.id -like 'Microsoft.Platform*') {
                # If packageId starts with Microsoft.Platform then use the packageId for the packageId
                $appName = 'Platform'
            }
            $returnValue = @([PSCustomObject]@{
                "Publisher" = $manifest.package.metadata.authors
                "Name" = $appName
                "id" = $appId
                "Version" = $manifest.package.metadata.version
            })
            $dependenciesErr = ''
            if ($manifest.package.metadata.PSObject.Properties.Name -eq 'Dependencies') {
                $dependencies = $manifest.package.metadata.Dependencies.GetEnumerator()
            }
            else {
                $dependencies = @()
            }
            foreach($dependency in $dependencies) {
                if (-not $installedPlatform) {
                    $installedPlatform = $installedApps+$returnValue | Where-Object { $_ -and $_.Name -eq 'Platform' } | Select-Object -ExpandProperty Version
                }
                $dependencyVersion = $dependency.Version
                $dependencyId = $dependency.Id
                $dependencyCountry = ''
                $downloadIt = $false
                if ($dependencyId -match '^Microsoft\.Platform(\.symbols)?$') {
                    $dependencyPublisher = 'Microsoft'
                    # Dependency is to the platform
                    if ($installedPlatform) {
                        if (!([NuGetFeed]::IsVersionIncludedInRange($installedPlatform, $dependencyVersion))) {
                            # The NuGet package found isn't compatible with the installed platform
                            $dependenciesErr = "NuGet package $packageId (version $packageVersion) requires platform $dependencyVersion. You cannot install it on version $installedPlatform"
                        }
                        $downloadIt = $false
                    }
                    else {
                        $downloadIt = ($downloadDependencies -eq 'all')
                    }
                }
                elseif ($dependencyId -match '^([^\.]+\.)?Application(\.[^\.]+)?(\.symbols)?$') {
                    # Dependency is to the application
                    $dependencyPublisher = $matches[1].TrimEnd('.')
                    $dependencyCountry = "$($matches[2])".TrimStart('.')
                    $installedApp = $installedApps | Where-Object { $_ -and $_.Name -eq 'Application' }
                    if ($installedApp) {
                        if (!([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $dependencyVersion))) {
                            $dependenciesErr = "NuGet package $packageId (version $packageVersion) requires application $dependencyVersion. You cannot install it on version $($installedApp.Version)"
                        }
                        $downloadIt = $false
                    }
                    else {
                        $downloadIt = ($downloadDependencies -eq 'all' -or $downloadDependencies -eq 'allButPlatform')
                    }
                }
                else {
                    $dependencyPublisher = ''
                    if ($dependencyId -match '^([^\.]+)\.([^\.]+)(\.[^\.][^\.])?(\.symbols)?(\.[0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12})?$') {
                        # Matches publisher.name[.country][.symbols][.appId] format (country section is only for microsoft apps)
                        $dependencyPublisher = $matches[1]
                        if ($dependencyPublisher -eq 'microsoft') {
                            $dependencyCountry = "$($matches[3])".TrimStart('.')
                        }
                    }
                    $installedApp = $installedApps | Where-Object { $_ -and $_.id -and $dependencyId -like "*$($_.id)*" }  | Sort-Object -Property @{ "Expression" = "[System.Version]Version" } -Descending | Select-Object -First 1
                    if ($installedApp) {
                        # Dependency is already installed, check version number
                        if (!([NuGetFeed]::IsVersionIncludedInRange($installedApp.Version, $dependencyVersion))) {
                            # The version installed isn't compatible with the NuGet package found
                            $dependenciesErr = "Dependency $dependencyId is already installed with version $($installedApp.Version), which is not compatible with the version $dependencyVersion required by the NuGet package $packageId (version $packageVersion))"
                        }
                    }
                    elseif ($downloadDependencies -eq 'own') {
                        $downloadIt = ($dependencyPublisher -eq [NugetFeed]::Normalize($manifest.package.metadata.authors))
                    }
                    elseif ($downloadDependencies -eq 'allButMicrosoft') {
                        # Download if publisher isn't Microsoft (including if publisher is empty)
                        $downloadIt = ($dependencyPublisher -ne 'Microsoft')
                    }
                    elseif ($dependencyId -match '^([^\.]+)\.([^\.]+)\.runtime\-[0-9]+\-[0-9]+\-[0-9]+\-[0-9]+$') {
                        $downloadIt = $true
                    }
                    else {
                        $downloadIt = ($downloadDependencies -ne 'none')
                    }
                }
                # When downloading symbols, country will be symbols if no specific country is specified
                if ($dependencyCountry -eq 'symbols') {
                    $dependencyCountry = ''
                }
                if ($installedCountry -and $dependencyCountry -and ($installedCountry -ne $dependencyCountry)) {
                    # The NuGet package found isn't compatible with the installed application
                    Write-Host "WARNING: NuGet package $packageId (version $packageVersion) requires $dependencyCountry application. You have $installedCountry application installed"
                }                   
                if ($dependenciesErr) {
                    if (@('LatestMatching', 'EarliestMatching') -notcontains $select) {
                        throw $dependenciesErr
                    }
                    else {
                        # If we are looking for the earliest/latest matching version, then we can try to find another version
                        Write-Host "WARNING: $dependenciesErr"
                        break
                    }
                }
                if ($downloadIt) {
                    if ($dependencyVersion.StartsWith('[') -and $select -eq 'Exact') {
                        # Downloading Microsoft packages for a specific version
                        $dependencyVersion = $version
                    }
                    $returnValue += Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $dependencyId -version $dependencyVersion -folder $package -copyInstalledAppsToFolder $copyInstalledAppsToFolder -installedPlatform $installedPlatform -installedCountry $installedCountry -installedApps @($installedApps + $returnValue) -downloadDependencies $downloadDependencies -verbose:($VerbosePreference -eq 'Continue') -select $select -allowPrerelease:$allowPrerelease -checkLocalVersion
                }
            }
            if ($dependenciesErr) {
                # If we are looking for the earliest/latest matching version, then we can try to find another version
                $excludeVersions += $packageVersion
                Remove-Item -Path $package -Recurse -Force
                continue
            }
            if ($installedCountry -and (Test-Path (Join-Path $package $installedCountry) -PathType Container)) {
                # NuGet packages of Runtime packages might exist in different versions for different countries
                # The runtime package might contain C# invoke calls with different methodis for different countries
                # if the installedCountry doesn't have a special version, then the w1 version is used (= empty string)
                # If the package contains a country specific folder, then use that
                Write-Host "Using country specific folder $installedCountry"
                $appFiles = Get-Item -Path (Join-Path $package "$installedCountry/*.app")
            }
            else {
                $appFiles = Get-Item -Path (Join-Path $package "*.app")
            }

            foreach($appFile in $appFiles) {
                $targetFolders = @($folder)
                if ($copyInstalledAppsToFolder) {
                    $targetFolders += @($copyInstalledAppsToFolder)
                }
                $manifest = Get-AppJsonFromAppFile -appFile $appFile.FullName
                Write-Host "Found app file for package $($manifest.Name)"
                foreach ($currTargetFolder in $targetFolders) {
                    if (-not (Test-Path -Path $currTargetFolder -PathType Container)) {
                        New-Item -Path $currTargetFolder -ItemType Directory | Out-Null
                    }
                    $appFileName = "$($manifest.Publisher)_$($manifest.Name)_$($manifest.Version)".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
                    $targetFilePath = Join-Path -Path $currTargetFolder -ChildPath "$($appFileName).app"
                    Write-Host "Copying $($appFileName) to $currTargetFolder"
                    Copy-Item $appFile.FullName -Destination $targetFilePath -Force
                }
            }
            Remove-Item -Path $package -Recurse -Force
            break
        }
    }
    return $returnValue
}
catch {
    Write-Host -ForegroundColor Red "Error Message: $($_.Exception.Message.Replace("`r",'').Replace("`n",' '))`r`nStackTrace: $($_.ScriptStackTrace)"
    throw
}
}
Set-Alias -Name Copy-BcNuGetPackageToFolder -Value Download-BcNuGetPackageToFolder
Export-ModuleMember -Function Download-BcNuGetPackageToFolder -Alias Copy-BcNuGetPackageToFolder
