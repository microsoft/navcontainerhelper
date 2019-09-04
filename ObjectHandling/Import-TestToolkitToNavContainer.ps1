<# 
 .Synopsis
  Import TestToolkit to Nav Container
 .Description
  Import the objects from the TestToolkit to the Nav Container.
  The TestToolkit objects are already in a folder on the NAV on Docker image from version 0.0.4.3
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter includeTestLibrariesOnly
  Only import TestLibraries (do not import Test Codeunits)
 .Parameter testToolkitCountry
  Only import TestToolkit objects for a specific country.
  You must specify the country code that is used in the TestToolkit object name (e.g. CA, US, MX, etc.).
  This parameter only needs to be used in the event there are multiple country-specific sets of objects in the TestToolkit folder.
 .Parameter doNotUpdateSymbols
  Add this switch to avoid updating symbols when importing the test toolkit
 .Parameter ImportAction
  Specifies the import action. Default is Overwrite
 .Parameter doNotUseRuntimePackages
  Include the doNotUseRuntimePackages switch if you do not want to cache and use the test apps as runtime packages (only 15.x containers)
 .Example
  Import-TestToolkitToNavContainer -containerName test2
  .Example
  Import-TestToolkitToNavContainer -containerName test2 -testToolkitCountry US
#>
function Import-TestToolkitToNavContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerName, 
        [PSCredential] $sqlCredential = $null,
        [switch] $includeTestLibrariesOnly,
        [string] $testToolkitCountry,
        [switch] $doNotUpdateSymbols,
        [ValidateSet("Overwrite","Skip")]
        [string] $ImportAction = "Overwrite",
        [switch] $doNotUseRuntimePackages
    )

    $inspect = docker inspect $containerName | ConvertFrom-Json
    if ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -eq 0) {
        throw "Container $containerName is not a NAV container"
    }
    [System.Version]$version = $inspect.Config.Labels.version
    $country = $inspect.Config.Labels.country

    $config = Get-NavContainerServerConfiguration -ContainerName $containerName
    $doNotUpdateSymbols = $doNotUpdateSymbols -or (!(([bool]($config.PSobject.Properties.name -match "EnableSymbolLoadingAtServerStartup")) -and $config.EnableSymbolLoadingAtServerStartup -eq "True"))

    $generateSymbols = $false
    if ($version.Major -eq 14 -and !$doNotUpdateSymbols -and $config.ClientServicesCredentialType -ne "Windows") {
        $generateSymbols = $true
        $doNotUpdateSymbols = $true
    }

    if ($version.Major -ge 15) {
        if ($version -lt [Version]("15.0.35528.0")) {
            throw "Container $containerName (platform version $version) doesn't support the Test Toolkit yet, you need a laster version"
        }

        $appFiles = Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($includeTestLibrariesOnly, $navVersion, $doNotUseRuntimePackages)
            $apps = "Microsoft_Any.app", "Microsoft_Library Assert.app", "Microsoft_Test Runner.app" | % {
                @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
            }
            $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
            if (Test-Path $mockAssembliesPath) {
                $serviceTierAddInsFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins").FullName
                if (!(Test-Path (Join-Path $serviceTierAddInsFolder "Mock Assemblies"))) {
                    new-item -itemtype symboliclink -path $serviceTierAddInsFolder -name "Mock Assemblies" -value $mockAssembliesPath | Out-Null
                }
                $apps += "Microsoft_System Application Test Library.app", "Microsoft_Tests-TestLibraries.app" | % {
                    @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
                }

                if (!$includeTestLibrariesOnly) {
                    $apps += @(get-childitem -Path "C:\Applications\*.*" -recurse -filter "Microsoft_Tests-*.app") | Where-Object { $_ -notlike "*\Microsoft_Tests-TestLibraries.app" -and $_ -notlike "*\Microsoft_Tests-Marketing.app" -and $_ -notlike "*\Microsoft_Tests-SINGLESERVER.app" }
                }
                $apps | % {
                    $appFile = Get-ChildItem -path "c:\applications.*\*.*" -recurse -filter ($_.Name).Replace(".app","_*.app")
                    if (!($appFile)) {
                        $appFile = $_
                    }

                    if (!$doNotUseRuntimePackages) {
                        $applicationsPath = "C:\ProgramData\NavContainerHelper\Extensions\Applications-$navVersion"
                        if (!(Test-Path $applicationsPath)) {
                            New-Item -Path $applicationsPath -ItemType Directory | Out-Null
                        }
                        $runtimeAppFile = "$applicationsPath\$($_.name.Replace('.app','.runtime.app'))"
                        $useRuntimeApp = $false
                        if ((Test-Path $runtimeAppFile) -and ((Get-Item $runtimeAppFile).Length -gt 0)) {
                            $appFile = $runtimeAppFile
                            $useRuntimeApp = $true
                        }
                    }

                    Write-Host "Publishing $appFile"
                    Publish-NavApp -ServerInstance $ServerInstance -Path $appFile -SkipVerification
                    $navAppInfo = Get-NAVAppInfo -Path $appFile
                    $appName = $navAppInfo.Name
                    $appPublisher = $navAppInfo.Publisher
                    $appVersion = $navAppInfo.Version
                    Sync-NavTenant -ServerInstance $ServerInstance -Tenant default -Force
                    Sync-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant default -force -WarningAction Ignore
                    Install-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant default
                    if (!$doNotUseRuntimePackages -and !$useRuntimeApp) {
                        Get-NavAppRuntimePackage -ServerInstance $serverInstance -Publisher $appPublisher -Name $appName -version $appVersion -Path $runtimeAppFile
                    }
                }
            }
        } -argumentList $includeTestLibrariesOnly, "$version-$country", $doNotUseRuntimePackages
        Write-Host -ForegroundColor Green "TestToolkit successfully imported"
    }
    else {
        $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential -doNotAskForCredential
        Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param([PSCredential]$sqlCredential, $includeTestLibrariesOnly, $testToolkitCountry, $doNotUpdateSymbols, $ImportAction)
        
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
    
        } -ArgumentList $sqlCredential, $includeTestLibrariesOnly, $testToolkitCountry, $doNotUpdateSymbols, $ImportAction
    
        if ($generateSymbols) {
            Generate-SymbolsInNavContainer -containerName $containerName -sqlCredential $sqlCredential
        }
        Write-Host -ForegroundColor Green "TestToolkit successfully imported"
    }
}
Set-Alias -Name Import-TestToolkitToBCContainer -Value Import-TestToolkitToNavContainer
Export-ModuleMember -Function Import-TestToolkitToNavContainer -Alias Import-TestToolkitToBCContainer
