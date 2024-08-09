﻿<# 
 .Synopsis
  Import TestToolkit to BC Container
 .Description
  Import the objects from the TestToolkit to the BC Container.
  The TestToolkit objects are already in a folder on the NAV on Docker image from version 0.0.4.3
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter sqlCredential
  For 14.x containers and earlier. Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter credential
  For 15.x containers and later. Credentials for the admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter includeTestLibrariesOnly
  Only import TestLibrary Apps (do not import Test Apps)
 .Parameter includeTestFrameworkOnly
  Only import TestFramework Apps (do not import Test Apps or Test Library apps)
 .Parameter includeTestRunnerOnly
  Only import Test Runner (do not import Test Apps, Test Framework Apps or Test Library apps)
 .Parameter testToolkitCountry
  Only import TestToolkit objects for a specific country.
  You must specify the country code that is used in the TestToolkit object name (e.g. CA, US, MX, etc.).
  This parameter only needs to be used in the event there are multiple country-specific sets of objects in the TestToolkit folder.
 .Parameter doNotUpdateSymbols
  Add this switch to avoid updating symbols when importing the test toolkit
 .Parameter ImportAction
  Specifies the import action. Default is Overwrite
 .Parameter scope
  Specify Global or Tenant based on how you want to publish the package. Default is Global
 .Parameter tenant
  Tenant in which you want to install the test framework (default is default)
 .Parameter useDevEndpoint
  Specify the useDevEndpoint switch if you want to publish using the Dev Endpoint (like VS Code). This allows VS Code to re-publish.
 .Parameter doNotUseRuntimePackages
  Include the doNotUseRuntimePackages switch if you do not want to cache and use the test apps as runtime packages (only 15.x containers)
 .Parameter replaceDependencies
  With this parameter, you can specify a hashtable, describring that the specified dependencies in the apps being published should be replaced
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the function will import test toolkit to the online Business Central Environment specified
  Only Test Runner and Test Framework are/will be available in the online Business Central environment
 .Parameter environment
  Environment in which you want to import test toolkit.
 .Example
  Import-TestToolkitToBcContainer -containerName test2
  .Example
  Import-TestToolkitToBcContainer -containerName test2 -testToolkitCountry US
  .Example
  Import-TestToolkitToBcContainer -containerName test2 -includeTestLibrariesOnly -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
function Import-TestToolkitToBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $compilerFolder = '',
        [PSCredential] $sqlCredential = $null,
        [PSCredential] $credential = $null,
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [switch] $includeTestRunnerOnly,
        [switch] $includePerformanceToolkit,
        [string] $testToolkitCountry,
        [switch] $doNotUpdateSymbols,
        [ValidateSet("Overwrite","Skip")]
        [string] $ImportAction = "Overwrite",
        [switch] $doNotUseRuntimePackages = $true,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Global','Tenant')]
        [string] $scope,
        [string] $tenant = "default",
        [switch] $useDevEndpoint,
        [hashtable] $replaceDependencies = $null,
        [Hashtable] $bcAuthContext,
        [string] $environment

    )

$telemetryScope = InitTelemetryScope `
                    -name $MyInvocation.InvocationName `
                    -parameterValues $PSBoundParameters `
                    -includeParameters @("containerName","includeTestLibrariesOnly","includeTestFrameworkOnly","includeTestRunnerOnly","includePerformanceToolkit","testToolkitCountry")
try {

    if ($replaceDependencies) {
        $doNotUseRuntimePackages = $true
    }
    if (!($scope)) {
        if ($useDevEndpoint) {
            $scope = "tenant"
        }
        else {
            $scope = "global"
        }
    }

    if ($bcAuthContext -and $environment) {
        $appFiles = GetTestToolkitApps -containerName $containerName -compilerFolder $compilerFolder -includeTestRunnerOnly:$includeTestRunnerOnly -includeTestFrameworkOnly:$includeTestFrameworkOnly -includeTestLibrariesOnly:$includeTestLibrariesOnly -includePerformanceToolkit:$includePerformanceToolkit
        $installedApps = Get-BcPublishedApps -bcAuthContext $bcauthcontext -environment $environment | Where-Object { $_.state -eq "installed" }
        $appFiles | ForEach-Object {
            if ($compilerFolder) {
                $appInfo = Get-AppJsonFromAppFile -appFile $_
                $appVersion = [Version]$appInfo.Version
                $appId = $appInfo.Id
            }
            else {
                $appInfo = Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($appFile)
                    Get-NAVAppInfo -Path $appFile
                } -argumentList $_ | Where-Object { $_ -isnot [System.String] }
                $appVersion = $appInfo.Version
                $appId = $appInfo.AppId
            }

            $targetVersion = ""
            if ($appVersion.Major -eq 18 -and $appVersion.Minor -eq 0) {
                $targetVersion = "18.0.23013.23913"
            }
            $installedApp = $installedApps | Where-Object { $_.id -eq $appId -and (($targetVersion -eq "") -or ([Version]($_.version) -ge [Version]$targetVersion)) }
            if ($installedApp) {
                Write-Host "Skipping app '$($installedApp.name)' as it is already installed"
            }
            else {
                Install-BcAppFromAppSource -bcAuthContext $bcauthcontext -environment $environment -appId $appId -appVersion $targetVersion -acceptIsvEula -installOrUpdateNeededDependencies
            }
        }
        Write-Host -ForegroundColor Green "TestToolkit successfully published"
    }
    else {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -eq 0 -or $inspect.Config.Labels.maintainer -ne "Dynamics SMB") {
            throw "Container $containerName is not a Business Central container"
        }
        [System.Version]$version = $inspect.Config.Labels.version
        $country = $inspect.Config.Labels.country
    
        $isBcSandbox = $inspect.Config.Env | Where-Object { $_ -eq "IsBcSandbox=Y" }
    
        $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName

        $doNotUpdateSymbols = $doNotUpdateSymbols -or (!(([bool]($customConfig.PSobject.Properties.name -eq "EnableSymbolLoadingAtServerStartup")) -and $customConfig.EnableSymbolLoadingAtServerStartup -eq "True"))
    
        $generateSymbols = $false
        if ($version.Major -eq 14 -and !$doNotUpdateSymbols -and $customConfig.ClientServicesCredentialType -ne "Windows") {
            $generateSymbols = $true
            $doNotUpdateSymbols = $true
        }

        if ($version.Major -ge 15) {
            if ($version -lt [Version]("15.0.35528.0")) {
                throw "Container $containerName (platform version $version) doesn't support the Test Toolkit yet, you need a laster version"
            }
    
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
                if (Test-Path $mockAssembliesPath) {
                    $serviceTierAddInsFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins").FullName
                    if (!(Test-Path (Join-Path $serviceTierAddInsFolder "Mock Assemblies"))) {
                        new-item -itemtype symboliclink -path $serviceTierAddInsFolder -name "Mock Assemblies" -value $mockAssembliesPath | Out-Null
                        Set-NavServerInstance $serverInstance -restart
                        while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
                            Start-Sleep -Seconds 1
                        }
                    }
                }
            }
    
            $appFiles = GetTestToolkitApps -containerName $containerName -includeTestRunnerOnly:$includeTestRunnerOnly -includeTestFrameworkOnly:$includeTestFrameworkOnly -includeTestLibrariesOnly:$includeTestLibrariesOnly -includePerformanceToolkit:$includePerformanceToolkit

            $publishParams = @{}
            if ($version.Major -ge 18 -and $version.Major -lt 20 -and ($appFiles | Where-Object { $name = [System.IO.Path]::GetFileName($_); ($name -eq "Microsoft_Performance Toolkit.app" -or ($name -like "Microsoft_Performance Toolkit_*.*.*.*.app" -and $name -notlike "*.runtime.app")) })) {
                $BCPTLogEntryAPIsrc = Join-Path $PSScriptRoot "..\AppHandling\BCPTLogEntryAPI"
                $appJson = [System.IO.File]::ReadAllLines((Join-Path $BCPTLogEntryAPIsrc "app.json")) | ConvertFrom-Json
                $internalsVisibleTo = @{ "id" = $appJson.id; "name" = $appJson.name; "publisher" = $appjson.publisher }
                $publishParams += @{
                    "internalsVisibleTo" = $internalsVisibleTo
                    "replacePackageId" = $true
                }

                Get-BcContainerAppInfo -containerName $containerName | Where-Object { $_.Dependencies | Where-Object { $_ -like 'Performance Toolkit, Microsoft,*' } } | ForEach-Object {
                    UnPublish-BcContainerApp -containerName $containerName -publisher $_.Publisher -name $_.Name -version $_.Version -unInstall -force
                }
                
                UnPublish-BcContainerApp -containerName $containerName -publisher "microsoft" -name "Performance Toolkit" -unInstall -force
            }
    
            if (!$doNotUseRuntimePackages) {
                if ($isBcSandbox) {
                    $folderPrefix = "sandbox"
                }
                else {
                    $folderPrefix = "onprem"
                }
                $applicationsPath = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$folderPrefix-Applications-$Version-$country"
                if (!(Test-Path $applicationsPath)) {
                    New-Item -Path $applicationsPath -ItemType Directory | Out-Null
                }
            }
    
            $appFiles | ForEach-Object {
                $appFile = $_
                if (!$doNotUseRuntimePackages) {
                    $name = [System.IO.Path]::GetFileName($appFile)
                    $runtimeAppFile = "$applicationsPath\$($name.Replace('.app','.runtime.app'))"
                    $useRuntimeApp = $false
                    if (Test-Path $runtimeAppFile) {
                        if ((Get-Item $runtimeAppFile).Length -eq 0) {
                            Remove-Item $runtimeAppFile -force
                        }
                        else {
                            $appFile = $runtimeAppFile
                            $useRuntimeApp = $true
                        }
                    }
                }
    
                $tenantAppInfo = Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($appFile, $tenant)
                    $navAppInfo = Get-NAVAppInfo -Path $appFile
                    (Get-NAVAppInfo -ServerInstance $serverInstance -Name $navAppInfo.Name -Publisher $navAppInfo.Publisher -Version $navAppInfo.Version -tenant $tenant -tenantSpecificProperties)
                } -argumentList $appFile, $tenant | Where-Object { $_ -isnot [System.String] }

                if ($tenantAppInfo) {
                    if ($tenantAppInfo.IsInstalled) {
                        Write-Host "Skipping app '$appFile' as it is already installed"
                    }
                    else {
                        Sync-BcContainerApp -containerName $containerName -tenant $tenant -appName $tenantAppInfo.Name -appPublisher $tenantAppInfo.Publisher -appVersion $tenantAppInfo.Version -Force
                        Install-BcContainerApp -containerName $containerName -tenant $tenant -appName $tenantAppInfo.Name -appPublisher $tenantAppInfo.Publisher -appVersion $tenantAppInfo.Version -Force
                    }
                }
                else {
                    $name = [System.IO.Path]::GetFileName($appFile)
                    if ( $name -eq "Microsoft_Performance Toolkit.app" -or ($name -like "Microsoft_Performance Toolkit_*.*.*.*.app" -and $name -notlike "*.runtime.app") ) {
                        Publish-BcContainerApp -containerName $containerName @publishParams -appFile ":$appFile" -skipVerification -sync -install -scope $scope -useDevEndpoint:$useDevEndpoint -replaceDependencies $replaceDependencies -credential $credential -tenant $tenant
                    }
                    else {
                        Publish-BcContainerApp -containerName $containerName -appFile ":$appFile" -skipVerification -sync -install -scope $scope -useDevEndpoint:$useDevEndpoint -replaceDependencies $replaceDependencies -credential $credential -tenant $tenant
                    }
        
                    if (!$doNotUseRuntimePackages -and !$useRuntimeApp) {
                        Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($appFile, $tenant, $runtimeAppFile)
                            
                            $navAppInfo = Get-NAVAppInfo -Path $appFile
                            $appPublisher = $navAppInfo.Publisher
                            $appName = $navAppInfo.Name
                            $appVersion = $navAppInfo.Version
        
                            Get-NavAppRuntimePackage -ServerInstance $serverInstance -Publisher $appPublisher -Name $appName -version $appVersion -Path $runtimeAppFile -Tenant $tenant
                        } -argumentList $appFile, $tenant, (Get-BcContainerPath -containerName $containerName -path $runtimeAppFile -throw)
                    }
                }
            }
            Write-Host -ForegroundColor Green "TestToolkit successfully imported"
        }
        else {
            $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential -doNotAskForCredential
            Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param([PSCredential]$sqlCredential, $includeTestLibrariesOnly, $testToolkitCountry, $doNotUpdateSymbols, $ImportAction)
            
                $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
                [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
                $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
                $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
                $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
                $managementServicesPort = $customConfig.SelectSingleNode("//appSettings/add[@key='ManagementServicesPort']").Value
                if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
           
                $params = @{}
                if ($sqlCredential) {
                    $params = @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
                }
                if ($testToolkitCountry) {
                    $fileFilter = "*.$testToolkitCountry.fob"
                }
                else {
                    $fileFilter = "*.fob"
                }
                Get-ChildItem -Path "C:\TestToolKit" -Filter $fileFilter | ForEach-Object { 
                    if (!$includeTestLibrariesOnly -or $_.Name.StartsWith("CALTestLibraries")) {
                        $objectsFile = $_.FullName
                        Write-Host "Importing Objects from $objectsFile (container path)"
                        $databaseServerParameter = $databaseServer
        
                        if (!$doNotUpdateSymbols) {
                            Write-Host "Generating Symbols while importing"
                            # HACK: Parameter insertion...
                            # generatesymbolreference is not supported by Import-NAVApplicationObject yet
                            # insert an extra parameter for the finsql command by splitting the filter property
                            $databaseServerParameter = '",generatesymbolreference=1,ServerName="'+$databaseServer
                        }
            
                        Import-NAVApplicationObject @params -Path $objectsFile `
                                                    -DatabaseName $databaseName `
                                                    -DatabaseServer $databaseServerParameter `
                                                    -ImportAction $ImportAction `
                                                    -SynchronizeSchemaChanges No `
                                                    -NavServerName localhost `
                                                    -NavServerInstance $ServerInstance `
                                                    -NavServerManagementPort "$managementServicesPort" `
                                                    -Confirm:$false
            
                    }
                }
        
                # Sync after all objects hav been imported
                Get-NAVTenant -ServerInstance $ServerInstance | Sync-NavTenant -Mode ForceSync -Force
        
            } -ArgumentList $sqlCredential, ($includeTestLibrariesOnly -or $includeTestFrameworkOnly), $testToolkitCountry, $doNotUpdateSymbols, $ImportAction
        
            if ($generateSymbols) {
                Write-Host "Generating symbols"
                Generate-SymbolsInNavContainer -containerName $containerName -sqlCredential $sqlCredential
            }
            Write-Host -ForegroundColor Green "TestToolkit successfully imported"
        }
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Import-TestToolkitToNavContainer -Value Import-TestToolkitToBcContainer
Export-ModuleMember -Function Import-TestToolkitToBcContainer -Alias Import-TestToolkitToNavContainer
