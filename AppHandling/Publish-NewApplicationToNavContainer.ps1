<# 
 .Synopsis
  Publish an AL Application (including Base App) to a NAV/BC Container
 .Description
  This function will replace the existing application (including base app) with a new application
  The application will be deployed using developer mode (same as used by VS Code)
 .Parameter containerName
  Name of the container to which you want to publish your AL Project
 .Parameter appFile
  Path of the appFile
 .Parameter appDotNetPackagesFolder
  Location of prokect specific dotnet reference assemblies. Default means that the app only uses standard DLLs.
  If your project is using custom DLLs, you will need to place them in this folder and the folder needs to be shared with the container.
 .Parameter credential
  Credentials of the container super user if using NavUserPassword authentication
 .Parameter useCleanDatabase
  Add this switch if you want to uninstall all extensions and remove all C/AL objects in the range 1..1999999999.
  This switch (or useNewDatabase) is needed when turning a C/AL container into an AL Container.
 .Parameter useNewDatabase
  Add this switch if you want to create a new and empty database in the container
  This switch (or useCleanDatabase) is needed when turning a C/AL container into an AL Container.
 .Parameter companyName
  CompanyName when using -useNewDatabase. Default is My Company.
 .Parameter doNotUseDevEndpoint
  Specify this parameter to deploy the application to the global scope instead of the developer (tenant) scope
 .Parameter saveData
  Add this switch if you want to keep all extension data. Requires -useCleanDatabase
 .Parameter restoreApps
  Specify whether or not you want to restore previously installed apps in the container
 .Parameter replaceDependencies
  With this parameter, you can specify a hashtable, describring that the specified dependencies in the apps being published should be replaced
  If your application doesn't use the same appId, Publisher, Name and version as the original baseapp, you need to specify this if you want to restore apps
 .Example
  Publish-NewApplicationToNavContainer -containerName test `
                                       -appFile (Join-Path $alProjectFolder ".output\$($appPublisher)_$($appName)_$($appVersion).app") `
                                       -appDotNetPackagesFolder (Join-Path $alProjectFolder ".netPackages") `
                                       -credential $credential
 .Example
  Publish-NewApplicationToNavContainer -containerName test `
                                       -appFile (Join-Path $alProjectFolder ".output\$($appPublisher)_$($appName)_$($appVersion).app") `
                                       -appDotNetPackagesFolder (Join-Path $alProjectFolder ".netPackages") `
                                       -credential $credential `
                                       -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
function Publish-NewApplicationToNavContainer {
    Param (
        [string] $containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string] $appFile,
        [Parameter(Mandatory=$false)]
        [string] $appDotNetPackagesFolder,
        [Parameter(Mandatory=$false)]
        [pscredential] $credential,
        [switch] $useCleanDatabase,
        [switch] $useNewDatabase,
        [string] $companyName = "My Company",
        [switch] $doNotUseDevEndpoint,
        [switch] $saveData,
        [ValidateSet('No','Yes','AsRuntimePackages')]
        [string] $restoreApps = "No",
        [hashtable] $replaceDependencies = $null
    )

    $platform = Get-NavContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-NavContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform

    if ($platformversion.Major -lt 14) {
        throw "Container $containerName does not support the function Publish-NewApplicationToNavContainer"
    }

    Add-Type -AssemblyName System.Net.Http

    $customconfig = Get-NavContainerServerConfiguration -ContainerName $containerName
    $containerAppDotNetPackagesFolder = ""
    if ($appDotNetPackagesFolder -and (Test-Path $appDotNetPackagesFolder)) {
        $containerAppDotNetPackagesFolder = Get-NavContainerPath -containerName $containerName -path $appDotNetPackagesFolder -throw
    }
    
    Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param ( $appDotNetPackagesFolder )

        $serviceTierAddInsFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins").FullName
        $RTCFolder = "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client"
    
        if (!(Test-Path (Join-Path $serviceTierAddInsFolder "RTC"))) {
            if (Test-Path $RTCFolder -PathType Container) {
                new-item -itemtype symboliclink -path $ServiceTierAddInsFolder -name "RTC" -value (Get-Item $RTCFolder).FullName | Out-Null
            }
        }
        if (Test-Path (Join-Path $serviceTierAddInsFolder "ProjectDotNetPackages")) {
            (Get-Item (Join-Path $serviceTierAddInsFolder "ProjectDotNetPackages")).Delete()
        }
        if ($appDotNetPackagesFolder) {
            new-item -itemtype symboliclink -path $serviceTierAddInsFolder -name "ProjectDotNetPackages" -value $appDotNetPackagesFolder | Out-Null
        }

    } -argumentList $containerAppDotNetPackagesFolder

    if ($restoreApps -ne "No") {
        $containerFolder = Join-Path $ExtensionsFolder $containerName
        $appsFolder = Join-Path $containerFolder "Extensions"
        if (!(Test-Path $appsFolder)) {
            New-Item -Path $appsFolder -ItemType Directory | Out-Null
        }
        $installedApps = Get-NavContainerAppInfo -containerName $containerName -tenantSpecificProperties -sort DependenciesFirst | Where-Object { $_.Name -ne "System Application" -and $_.Name -ne "BaseApp" -and $_.Name -ne "Base Application" }
        $installedApps | ForEach-Object {
            if ($_.Scope -eq "Global" -and !$doNotUseDevEndpoint) {
                Write-Warning "Restoring apps to global scope might not work when publishing base app to dev endpoint. You might need to specify -doNotUseDevEndpoint"
            }
        }
        $installedApps | ForEach-Object {
            $installedAppFile = Join-Path $appsFolder "$($_.Publisher.Replace('/',''))_$($_.Name.Replace('/',''))_$($_.Version).app"
            if ($restoreApps -ne "Yes") {
                Write-Host "Downloading app $($_.Name) as runtime package"
                Get-BCContainerAppRuntimePackage -containerName $containerName -appName $_.Name -publisher $_.Publisher -appVersion $_.Version -appFile $installedAppFile -Tenant default | Out-Null
            }
            else {
                Get-BCContainerApp -containerName $containerName -appName $_.Name -publisher $_.Publisher -appVersion $_.Version -appFile $installedAppFile -Tenant default -credential $credential | Out-Null
            }
        }
    }
    if ($useCleanDatabase -or $useNewDatabase) {
        Clean-BcContainerDatabase -containerName $containerName -saveData:$saveData -saveOnlyBaseAppData:($restoreApps -eq "No") -useNewDatabase:$useNewDatabase -credential $credential
        
        if ($useNewDatabase) {
            New-CompanyInBCContainer -containerName $containerName -companyName $companyName
        }

    }

    $scope = "tenant"
    if ($doNotUseDevEndpoint) {
        $scope = "global"
    }
    Publish-BCContainerApp -containerName $containerName -appFile $appFile -scope $scope -credential $credential -useDevEndpoint:(!$doNotUseDevEndpoint) -skipVerification -sync -install

    if ($restoreApps -ne "No") {
        $installedApps | ForEach-Object {
            $installedAppFile = Join-Path $appsFolder "$($_.Publisher.Replace('/',''))_$($_.Name.Replace('/',''))_$($_.Version).app"
            if ($_.IsPublished) {
                try {
                    Publish-BCContainerApp -containerName $containerName -appFile $installedAppFile -skipVerification -sync -install:($_.IsInstalled) -scope $Scope -useDevEndpoint:(!$doNotUseDevEndpoint) -replaceDependencies $replaceDependencies
                }
                catch {
                    Write-Warning "Could not republish $installedAppFile"
                }
            }
        }
    }
}
Set-Alias -Name Publish-NewApplicationToBcContainer -Value Publish-NewApplicationToNavContainer
Export-ModuleMember -Function Publish-NewApplicationToNavContainer -Alias Publish-NewApplicationToBcContainer
