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
        [Parameter(Mandatory=$false)]
        [string] $nuGetToken = "",
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [System.Version] $version = [System.Version]'0.0.0.0',
        [string] $containerName = "",
        [Hashtable] $bcAuthContext,
        [string] $environment,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [string] $copyInstalledAppsToFolder = "",
        [switch] $skipVerification
    )

    if ($containerName -eq "" -and (!($bcAuthContext -and $environment))) {
        $containerName = $bcContainerHelperConfig.defaultContainerName
    }

    $installedApps = @()
    if ($bcAuthContext -and $environment) {
        $isCloudBcContainer = isCloudBcContainer -authContext $bcAuthContext -containerId $environment
        if ($isCloudBcContainer) {
            $installedApps = @(Invoke-ScriptInCloudBcContainer -authContext $bcAuthContext -containerId $environment -scriptblock {
                Get-NAVAppInfo -ServerInstance $serverInstance -TenantSpecificProperties -tenant 'default' | Where-Object { $_.IsInstalled -eq $true } | ForEach-Object { Get-NAVAppInfo -ServerInstance $serverInstance -TenantSpecificProperties -tenant 'default' -id $_.AppId -publisher $_.publisher -name $_.name -version $_.Version }
            } | ForEach-Object { @{ "Publisher" = $_.Publisher; "Name" = $_.Name; "Id" = $_.AppId; "Version" = $_.Version } } )
            # Get Country and Platform from the container
        }
        else {
            $envInfo = Get-BcEnvironments -bcAuthContext $bcAuthContext -environment $environment
            $installedPlatform = [System.Version]$envInfo.platformVersion
            $installedCountry = $envInfo.countryCode.ToLowerInvariant()
            $installedApps = @(Get-BcEnvironmentInstalledExtensions -bcAuthContext $authContext -environment $environment | ForEach-Object { @{ "Publisher" = $_.Publisher; "Name" = $_.displayName; "Id" = $_.Id; "Version" = [System.Version]::new($_.VersionMajor, $_.VersionMinor, $_.VersionBuild, $_.VersionRevision) } })
        }
    }
    else {
        $installedApps = @(Get-BcContainerAppInfo -containerName $containerName -installedOnly | ForEach-Object { @{ "Publisher" = $_.Publisher; "Name" = $_.Name; "Id" = $_.AppId; "Version" = $_.Version } } )
        $installedPlatform = [System.Version](Get-BcContainerPlatformVersion -containerOrImageName $containerName)
        $installedCountry = (Get-BcContainerCountry -containerOrImageName $containerName).ToLowerInvariant()
    }
    $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
    New-Item $tmpFolder -ItemType Directory | Out-Null
    try {
        Download-BcNuGetPackageToFolder -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version -appSymbolsFolder $tmpFolder -installedApps $installedApps -installedPlatform $installedPlatform -installedCountry $installedCountry
        $appFiles = Get-Item -Path (Join-Path $tmpFolder '*.app') | Select-Object -ExpandProperty FullName
        Publish-BcContainerApp -containerName $containerName -bcAuthContext $bcAuthContext -environment $environment -tenant $tenant -appFile $appFiles -sync -install -upgrade -checkAlreadyInstalled -skipVerification -copyInstalledAppsToFolder $copyInstalledAppsToFolder
    }
    finally {
        Remove-Item -Path $tmpFolder -Recurse -Force
    }
}
Export-ModuleMember -Function Publish-BcNuGetPackageToContainer
