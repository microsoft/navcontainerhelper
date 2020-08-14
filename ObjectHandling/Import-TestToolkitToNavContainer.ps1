<# 
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
  Only import TestLibraries (do not import Test Codeunits)
 .Parameter includeTestFrameworkOnly
  Only import TestFramework (do not import Test Codeunits nor TestLibraries)
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
 .Parameter useDevEndpoint
  Specify the useDevEndpoint switch if you want to publish using the Dev Endpoint (like VS Code). This allows VS Code to re-publish.
 .Parameter doNotUseRuntimePackages
  Include the doNotUseRuntimePackages switch if you do not want to cache and use the test apps as runtime packages (only 15.x containers)
 .Parameter replaceDependencies
  With this parameter, you can specify a hashtable, describring that the specified dependencies in the apps being published should be replaced
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
        [PSCredential] $sqlCredential = $null,
        [PSCredential] $credential = $null,
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [string] $testToolkitCountry,
        [switch] $doNotUpdateSymbols,
        [ValidateSet("Overwrite","Skip")]
        [string] $ImportAction = "Overwrite",
        [switch] $doNotUseRuntimePackages,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Global','Tenant')]
        [string] $scope,
        [switch] $useDevEndpoint,
        [hashtable] $replaceDependencies = $null
    )

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

    $inspect = docker inspect $containerName | ConvertFrom-Json
    if ($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -eq 0 -or $inspect.Config.Labels.maintainer -ne "Dynamics SMB") {
        throw "Container $containerName is not a Business Central container"
    }
    [System.Version]$version = $inspect.Config.Labels.version
    $country = $inspect.Config.Labels.country

    $config = Get-BcContainerServerConfiguration -ContainerName $containerName
    $doNotUpdateSymbols = $doNotUpdateSymbols -or (!(([bool]($config.PSobject.Properties.name -eq "EnableSymbolLoadingAtServerStartup")) -and $config.EnableSymbolLoadingAtServerStartup -eq "True"))

    $generateSymbols = $false
    if ($version.Major -eq 14 -and !$doNotUpdateSymbols -and $config.ClientServicesCredentialType -ne "Windows") {
        $generateSymbols = $true
        $doNotUpdateSymbols = $true
    }

    if ($version.Major -ge 15) {
        if ($version -lt [Version]("15.0.35528.0")) {
            throw "Container $containerName (platform version $version) doesn't support the Test Toolkit yet, you need a laster version"
        }

        $appFiles = Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($includeTestLibrariesOnly, $includeTestFrameworkOnly)


            # Add Test Framework
            $apps = @(get-childitem -Path "C:\Applications\TestFramework\TestLibraries\*.*" -recurse -filter "*.app")
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestRunner\*.*" -recurse -filter "*.app")

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

                if (!$includeTestFrameworkOnly) {
                    
                    # Add Test Libraries
                    $apps += "Microsoft_System Application Test Library.app", "Microsoft_Tests-TestLibraries.app" | % {
                        @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
                    }

                    if (!$includeTestLibrariesOnly) {

                        # Add Tests
                        $apps += @(get-childitem -Path "C:\Applications\*.*" -recurse -filter "Microsoft_Tests-*.app") | Where-Object { $_ -notlike "*\Microsoft_Tests-TestLibraries.app" -and $_ -notlike "*\Microsoft_Tests-Marketing.app" -and $_ -notlike "*\Microsoft_Tests-SINGLESERVER.app" }
                    }
                }
            }

            $apps | % {
                $appFile = Get-ChildItem -path "c:\applications.*\*.*" -recurse -filter ($_.Name).Replace(".app","_*.app")
                if (!($appFile)) {
                    $appFile = $_
                }
                $appFile
            }
        } -argumentList $includeTestLibrariesOnly, $includeTestFrameworkOnly

        if (!$doNotUseRuntimePackages) {
            $folderPrefix = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                if ($env:IsBcSandbox -eq "Y") {
                    "sandbox"
                }
                else {
                    "onprem"
                }
            }
            $applicationsPath = Join-Path $extensionsFolder "$folderPrefix-Applications-$Version-$country"
            if (!(Test-Path $applicationsPath)) {
                New-Item -Path $applicationsPath -ItemType Directory | Out-Null
            }
        }

        $appFiles | % {
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

            Publish-BcContainerApp -containerName $containerName -appFile ":$appFile" -skipVerification -sync -install -scope $scope -useDevEndpoint:$useDevEndpoint -replaceDependencies $replaceDependencies -credential $credential

            if (!$doNotUseRuntimePackages -and !$useRuntimeApp) {
                Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($appFile, $runtimeAppFile)
                    
                    $navAppInfo = Get-NAVAppInfo -Path $appFile
                    $appPublisher = $navAppInfo.Publisher
                    $appName = $navAppInfo.Name
                    $appVersion = $navAppInfo.Version

                    Get-NavAppRuntimePackage -ServerInstance $serverInstance -Publisher $appPublisher -Name $appName -version $appVersion -Path $runtimeAppFile -Tenant default
                } -argumentList $appFile, (Get-BcContainerPath -containerName $containerName -path $runtimeAppFile -throw)
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
                $params = @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
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
            Generate-SymbolsInBcContainer -containerName $containerName -sqlCredential $sqlCredential
        }
        Write-Host -ForegroundColor Green "TestToolkit successfully imported"
    }
}
Set-Alias -Name Import-TestToolkitToNavContainer -Value Import-TestToolkitToBcContainer
Export-ModuleMember -Function Import-TestToolkitToBcContainer -Alias Import-TestToolkitToNavContainer
