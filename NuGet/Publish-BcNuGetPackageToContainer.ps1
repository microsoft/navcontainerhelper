<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Publish Business Central NuGet Package to container
 .Description
  Publish Business Central NuGet Package to container
 .PARAMETER nuGetServerUrl
  NuGet Server URL
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
 .PARAMETER containerName
  Name of the container to publish to
  If not specified, the default container name is used
 .Parameter tenant
  The tenant in which you want to install the app
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the function will publish the app to the online Business Central Environment specified
 .Parameter environment
  Environment to use for publishing
 .Parameter copyInstalledAppsToFolder
  If specified, the installed apps will be copied to this folder in addition to being installed in the container
 .Parameter skipVerification
  Include this parameter if the app you want to publish is not signed
 .EXAMPLE
  Publish-BcNuGetPackageToContainer -containerName $containerName -packageName 'FreddyKristiansen.BingMapsPTE.165d73c1-39a4-4fb6-85a5-925edc1684fb' -version "2.0.0.0" -select earliest
#>
Function Publish-BcNuGetPackageToContainer {
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
        [ValidateSet('Earliest', 'EarliestMatching', 'Latest', 'LatestMatching', 'Exact', 'Any')]
        [string] $select = 'Latest',
        [string] $containerName = "",
        [Hashtable] $bcAuthContext,
        [string] $environment,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [string] $appSymbolsFolder = "",
        [string] $copyInstalledAppsToFolder = "",
        [switch] $skipVerification
    )

    if ($containerName -eq "" -and (!($bcAuthContext -and $environment))) {
        $containerName = $bcContainerHelperConfig.defaultContainerName
    }

    $installedApps = @()
    if ($bcAuthContext -and $environment) {
        $envInfo = Get-BcEnvironments -bcAuthContext $bcAuthContext -environment $environment
        $installedPlatform = [System.Version]$envInfo.platformVersion
        $installedCountry = $envInfo.countryCode.ToLowerInvariant()
        $installedApps = @(Get-BcEnvironmentInstalledExtensions -bcAuthContext $bcAuthContext -environment $environment | ForEach-Object { @{ "Publisher" = $_.Publisher; "Name" = $_.displayName; "Id" = $_.Id; "Version" = [System.Version]::new($_.VersionMajor, $_.VersionMinor, $_.VersionBuild, $_.VersionRevision) } })
    }
    else {
        $installedApps = @(Get-BcContainerAppInfo -containerName $containerName -installedOnly | ForEach-Object { @{ "Publisher" = $_.Publisher; "Name" = $_.Name; "Id" = "$($_.AppId)"; "Version" = $_.Version } } )
        $installedPlatform = [System.Version](Get-BcContainerPlatformVersion -containerOrImageName $containerName)
        $installedCountry = (Get-BcContainerCountry -containerOrImageName $containerName).ToLowerInvariant()
    }
    $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
    New-Item $tmpFolder -ItemType Directory | Out-Null
    try {
        if (Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version -appSymbolsFolder $tmpFolder -installedApps $installedApps -installedPlatform $installedPlatform -installedCountry $installedCountry -verbose:($VerbosePreference -eq 'Continue') -select $select) {
            $appFiles = Get-Item -Path (Join-Path $tmpFolder '*.app') | ForEach-Object {
                if ($appSymbolsFolder) {
                    Copy-Item -Path $_.FullName -Destination $appSymbolsFolder -Force
                }
                $_.FullName
            }
            Publish-BcContainerApp -containerName $containerName -bcAuthContext $bcAuthContext -environment $environment -tenant $tenant -appFile $appFiles -sync -install -upgrade -checkAlreadyInstalled -skipVerification -copyInstalledAppsToFolder $copyInstalledAppsToFolder
        }
        elseif ($ErrorActionPreference -eq 'Stop') {
            throw "No apps to publish"
        }
        else {
            Write-Host "No apps to publish"
        }
    }
    finally {
        Remove-Item -Path $tmpFolder -Recurse -Force
    }
}
Export-ModuleMember -Function Publish-BcNuGetPackageToContainer
