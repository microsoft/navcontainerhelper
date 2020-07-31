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
 .Parameter doNotCopyEntitlements
  Specify this parameter to avoid copying entitlements when using -useNewDatabase
 .Parameter copyTables
  Array if table names to copy from original database when using -useNewDatabase
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
  Publish-NewApplicationToBcContainer -containerName test `
                                      -appFile (Join-Path $alProjectFolder ".output\$($appPublisher)_$($appName)_$($appVersion).app") `
                                      -appDotNetPackagesFolder (Join-Path $alProjectFolder ".netPackages") `
                                      -credential $credential
 .Example
  Publish-NewApplicationToBcContainer -containerName test `
                                      -appFile (Join-Path $alProjectFolder ".output\$($appPublisher)_$($appName)_$($appVersion).app") `
                                      -appDotNetPackagesFolder (Join-Path $alProjectFolder ".netPackages") `
                                      -credential $credential `
                                      -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
function Publish-NewApplicationToBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $appFile,
        [Parameter(Mandatory=$false)]
        [string] $appDotNetPackagesFolder,
        [Parameter(Mandatory=$false)]
        [pscredential] $credential,
        [switch] $useCleanDatabase,
        [switch] $useNewDatabase,
        [switch] $doNotCopyEntitlements,
        [string[]] $copyTables = @(),
        [string] $companyName = "My Company",
        [switch] $doNotUseDevEndpoint,
        [switch] $saveData,
        [ValidateSet('No','Yes','AsRuntimePackages')]
        [string] $restoreApps = "No",
        [hashtable] $replaceDependencies = $null
    )

    $platform = Get-BcContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-BcContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform

    if ($platformversion.Major -lt 14) {
        throw "Container $containerName does not support the function Publish-NewApplicationToBcContainer"
    }

    Add-Type -AssemblyName System.Net.Http

    $customconfig = Get-BcContainerServerConfiguration -ContainerName $containerName
    $containerAppDotNetPackagesFolder = ""
    if ($appDotNetPackagesFolder -and (Test-Path $appDotNetPackagesFolder)) {
        $containerAppDotNetPackagesFolder = Get-BcContainerPath -containerName $containerName -path $appDotNetPackagesFolder -throw
    }
    
    Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param ( $appDotNetPackagesFolder )

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
            Set-NavServerInstance $serverInstance -restart
            while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
                Start-Sleep -Seconds 1
            }
        }

    } -argumentList $containerAppDotNetPackagesFolder

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    $appsFolder = Join-Path $containerFolder "Extensions"
    if (!(Test-Path $appsFolder)) {
        New-Item -Path $appsFolder -ItemType Directory | Out-Null
    }
    if ($restoreApps -ne "No") {
        $installedApps = Get-BcContainerAppInfo -containerName $containerName -tenantSpecificProperties -sort DependenciesFirst | Where-Object { $_.Name -ne "System Application" -and $_.Name -ne "BaseApp" -and $_.Name -ne "Base Application" }
        if ($restoreApps -eq "AsRuntimePackages" -and ($replaceDependencies)) {
            Write-Warning "ReplaceDependencies will not work with apps restored as runtime packages"
        }
    }
    else {
        $installedApps = Get-BcContainerAppInfo -containerName $containerName -tenantSpecificProperties | Where-Object { $_.Name -eq "Application" }
    }
    $applicationApp = $installedApps | Where-Object { $_.Name -eq "Application" }
    if ($applicationApp) {
        Write-Host "Application App Exists"
    }
    $warninggiven = $false
    $installedApps | ForEach-Object {
        if ($_.Scope -eq "Global" -and !$doNotUseDevEndpoint) {
            if (!$warninggiven) {
                Write-Warning "Restoring apps to global scope might not work when publishing base app to dev endpoint. You might need to specify -doNotUseDevEndpoint"
                $warninggiven = $true
            }
        }
    }
    $installedApps | ForEach-Object {
        $installedAppFile = Join-Path $appsFolder $("$($_.Publisher)_$($_.Name)_$($_.Version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
        if ($restoreApps -eq "AsRuntimePackages") {
            Write-Host "Downloading app $($_.Name) as runtime package"
            Get-BCContainerAppRuntimePackage -containerName $containerName -appName $_.Name -publisher $_.Publisher -appVersion $_.Version -appFile $installedAppFile -Tenant default | Out-Null
        }
        else {
            Get-BCContainerApp -containerName $containerName -appName $_.Name -publisher $_.Publisher -appVersion $_.Version -appFile $installedAppFile -Tenant default -credential $credential | Out-Null
        }
    }
    if ($useCleanDatabase -or $useNewDatabase) {
        Clean-BcContainerDatabase -containerName $containerName -saveData:$saveData -saveOnlyBaseAppData:($restoreApps -eq "No") -useNewDatabase:$useNewDatabase -doNotCopyEntitlements:$doNotCopyEntitlements -copyTables $copyTables -credential $credential -CompanyName $CompanyName
    }

    $scope = "tenant"
    if ($doNotUseDevEndpoint) {
        $scope = "global"
    }
    Publish-BCContainerApp -containerName $containerName -appFile $appFile -scope $scope -credential $credential -useDevEndpoint:(!$doNotUseDevEndpoint) -skipVerification -sync -install

    if ($restoreApps -ne "No") {
        $installedApps | ForEach-Object {
            $installedApp = $_
            $installedAppFile = Join-Path $appsFolder $("$($installedApp.Publisher)_$($installedApp.Name)_$($installedApp.Version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')

            if ($applicationApp) {
                if ($installedApp -eq $applicationApp) {
                    $replaceDeps = $replaceDependencies
                }
                elseif ($installedApp.Name -like "* language (*)" -and $installedApp.Publisher -eq "Microsoft") {
                    $replaceDeps = $replaceDependencies
                }
                else {
                    $replaceDeps = $null
                }
            }
            else {
                $replaceDeps = $replaceDependencies
            }

            if ($_.IsPublished) {
                try {
                    Publish-BCContainerApp -containerName $containerName -appFile $installedAppFile -skipVerification -sync -install:($installedApp.IsInstalled) -scope $Scope -useDevEndpoint:(!$doNotUseDevEndpoint) -replaceDependencies $replaceDeps -credential $credential -ShowMyCode "Check"                }
                catch {
                    $appFile = Invoke-ScriptInBCContainer -containerName $containername -scriptblock { Param($installedApp)
                        $filename = ""
                        $localdir = Get-Item -Path "c:\Applications.*"
                        if ($localdir) {
                            $filename = Get-ChildItem -Path $localdir.FullName -Filter "*.app" -Recurse | % {
                                $appInfo = Get-NavAppInfo -Path $_.FullName
                                if ("$($appInfo.Publisher)_$($appInfo.Name)_$($appInfo.Version)_$($appInfo.AppId)" -eq "$($installedApp.Publisher)_$($installedApp.Name)_$($installedApp.Version)_$($installedApp.AppId)") {
                                    $_.FullName
                                }
                            }
                        }
                        if (!$filename) {
                            $filename = Get-ChildItem -Path "c:\Applications" -Filter "*.app" -Recurse | % {
                                $appInfo = Get-NavAppInfo -Path $_.FullName
                                if ("$($appInfo.Publisher)_$($appInfo.Name)_$($appInfo.Version)_$($appInfo.AppId)" -eq "$($installedApp.Publisher)_$($installedApp.Name)_$($installedApp.Version)_$($installedApp.AppId)") {
                                    $_.FullName
                                }
                            }
                        }
                        $filename
                    } -argumentlist $installedapp
                    if ($appfile) {
                        try {
                            Publish-BCContainerApp -containerName $containerName -appFile ":$appFile" -skipVerification -sync -install:($installedApp.IsInstalled) -scope $Scope -useDevEndpoint:(!$doNotUseDevEndpoint) -replaceDependencies $replaceDeps -credential $credential
                        }
                        catch {
                            Write-Warning "Could not publish :$([System.IO.Path]::GetFileName($appFile)) - $($_.Exception.Message)"
                        }
                    }
                    else {
                        Write-Warning "Could not publish $([System.IO.Path]::GetFileName($installedAppFile)) - $($_.Exception.Message)"
                    }
                }
            }
        }
    }
}
Set-Alias -Name Publish-NewApplicationToNavContainer -Value Publish-NewApplicationToBcContainer
Export-ModuleMember -Function Publish-NewApplicationToBcContainer -Alias Publish-NewApplicationToNavContainer
