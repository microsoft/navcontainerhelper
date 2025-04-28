<#
 .Synopsis
  Run AL Pipeline
 .Description
  Run AL Pipeline
 .Parameter pipelineName
  The name of the pipeline or project.
 .Parameter baseFolder
  The baseFolder serves as the base Folder for all other parameters including a path (appFolders, testFolders, testResultFile, outputFolder, packagesFolder and buildArtifactFolder). This folder will be shared with the container as c:\sources
 .Parameter sharedFolder
  If a folder on the host computer is specified in the sharedFolder parameter, it will be shared with the container as c:\shared
 .Parameter licenseFile
  License file to use for AL Pipeline.
 .Parameter accept_insiderEula
  Switch, which you need to specify if you are going to create a container with an insider build of Business Central on Docker containers (See https://go.microsoft.com/fwlink/?linkid=2245051)
 .Parameter containerName
  This is the containerName going to be used for the build/test container. If not specified, the container name will be the pipeline name followed by -bld.
 .Parameter generateErrorLog
  Switch parameter on whether to generate an alerts log file. Default is false.
  If set to true, the `errorLog` argument is used when compiling the apps. The generated file will be named <appname>.errorLog.json and is placed in the same folder as the app file.
 .Parameter imageName
  If imageName is specified it will be used to build an image, which serves as a cache for faster container generation.
  Only speficy imagename if you are going to create multiple containers from the same artifacts.
 .Parameter enableTaskScheduler
  Include this switch if the Task Scheduler should be running inside the build/test container, as some app features rely on the Task Scheduler.
 .Parameter assignPremiumPlan
  Include this switch if the primary user in Business Central should have assign premium plan, as some app features require premium plan.
 .Parameter tenant
  If you specify a tenant name, a tenant with this name will be created and used for the entire process.
 .Parameter memoryLimit
  MemoryLimit is default set to 8Gb. This is fine for compiling small and medium size apps, but if your have a number of apps or your apps are large and complex, you might need to assign more memory.
 .Parameter auth
  Set auth to Windows, NavUserPassword or AAD depending on which authentication mechanism your container should use
 .Parameter credential
  These are the credentials used for the container. If not provided, the Run-AlPipeline function will generate a random password and use that.
 .Parameter companyName
  company to use for test execution (blank for default)
 .Parameter codeSignCertPfxFile
  A secure url to a code signing certificate for signing apps. Apps will only be signed if useDevEndpoint is NOT specified.
 .Parameter codeSignCertPfxPassword
  Password for the code signing certificate specified by codeSignCertPfxFile. Apps will only be signed if useDevEndpoint is NOT specified.
 .Parameter keyVaultCertPfxFile
  A secure url to a certificate for keyVault accessing from the container. This will be used in a call to Set-BcContainerKeyVaultAadAppAndCertificate after the container is created.
 .Parameter keyVaultCertPfxPassword
  Password for the keyVault certificate specified by keyVaultCertPfxFile. This will be used in a call to Set-BcContainerKeyVaultAadAppAndCertificate after the container is created.
 .Parameter keyVaultClientId
  ClientId for the keyVault certificate specified by keyVaultCertPfxFile. This will be used in a call to Set-BcContainerKeyVaultAadAppAndCertificate after the container is created.
 .Parameter installApps
  Array or comma separated list of 3rd party apps to install before compiling apps.
 .Parameter installTestApps
  Array or comma separated list of 3rd party test apps to install before compiling test apps.
 .Parameter installOnlyReferencedApps
  Switch indicating whether you want to only install referenced apps in InstallApps and InstallTestApps
 .Parameter generateDependencyArtifact
  Switch indicating whether you want to generate a folder with all installed dependency apps used during build
 .Parameter previousApps
  Array or comma separated list of previous version of apps
 .Parameter appFolders
  Array or comma separated list of folders with apps to be compiled, signed and published
 .Parameter testFolders
  Array or comma separated list of folders with test apps to be compiled, published and run
 .Parameter bcptTestFolders
  Array or comma separated list of folders with bcpt test apps to be compiled, published and run
 .Parameter pageScriptingTests
  Array or comma separated list of filespecs with pageScripting tests, to be run after the apps have been compiled and tested
 .Parameter additionalCountries
  Array or comma separated list of countries to test
 .Parameter restoreDatabases
  Array or comma seperated list of events, indicating when you want to start with clean databases in the container. Possible events are: BeforeBcpTests, BeforePageScriptingTests, BeforeEachTestApp, BeforeEachBcptTestApp, BeforeEachPageScriptingTest
 .Parameter appVersion
  Major and Minor version for build (ex. "18.0"). Will be stamped into the build part of the app.json version number property.
 .Parameter appBuild
  Build number for build. Will be stamped into the build part of the app.json version number property.
 .Parameter appRevision
  Revision number for build. Will be stamped into the revision part of the app.json version number property.
 .Parameter applicationInsightsKey
  ApplicationInsightsKey to be stamped into app.json for all apps
 .Parameter applicationInsightsConnectionString
  ApplicationInsightsConnectionString to be stamped into app.json for all apps
 .Parameter buildOutputFile
  Filename in which you want the build output to be written. Default is none, meaning that build output will not be written to a file, but only on screen.
 .Parameter containerEventLogFile
  Filename in which you want the build output to be written. Default is none, meaning that build output will not be written to a file, but only on screen.
 .Parameter testResultsFile
  Filename in which you want the test results to be written. Default is TestResults.xml, meaning that test results will be written to this filename in the base folder. This parameter is ignored if doNotRunTests is included.
 .Parameter bcptTestResultsFile
  Filename in which you want the bcpt test results to be written. Default is TestResults.xml, meaning that test results will be written to this filename in the base folder. This parameter is ignored if doNotRunBcptTests is included.
 .Parameter pageScriptingTestResultsFile
  File in which you want the page scripting test results to be written in JUnit format. Default is PageScriptingTestResults.xml.
 .Parameter pageScriptingTestResultsFolder
  Folder in which you want the page scripting test results to be written. Default is PageScriptingTestResults, meaning that test result detailss will be written to folders underneath this folder, relative to the base folder. This parameter is ignored if doNotRunPageScriptingTests is included.
 .Parameter testResultsFormat
  Format of test results file. Possible values are XUnit or JUnit. Both formats are XML based test result formats.
 .Parameter packagesFolder
  This is the folder (relative to base folder) where symbols are downloaded  and compiled apps are placed. Only relevant when not using useDevEndpoint
 .Parameter outputFolder
  This is the folder (relative to base folder) where compiled apps are placed. Only relevant when not using useDevEndpoint.
 .Parameter artifact
  The description of which artifact to use. This can either be a URL (from Get-BcArtifactUrl) or in the format storageAccount/type/version/country/select, where these values are transferred as parameters to Get-BcArtifactUrl. Default value is ///us/current.
 .Parameter useGenericImage
  Specify a private (or special) generic image to use for the Container OS. Default is calling Get-BestGenericImageName.
 .Parameter buildArtifactFolder
  If this folder is specified, the build artifacts will be copied to this folder.
 .Parameter createRuntimePackages
  Include this switch if you want to create runtime packages of all apps. The runtime packages will also be signed (if certificate is provided) and copied to artifacts folder.
 .Parameter installTestRunner
  Include this switch to include the test runner in the container before compiling apps and test apps. The Test Runner includes the following apps: Microsoft Test Runner.
 .Parameter installTestFramework
  Include this switch to include the test framework in the container before compiling apps and test apps. The Test Framework includes the following apps: Microsoft Any, Microsoft Library Assert, Microsoft Library Variable Storage and Microsoft Test Runner.
 .Parameter installTestLibraries
  Include this switch to include the test libraries in the container before compiling apps and test apps. The Test Libraries includes all the Test Framework apps and the following apps: Microsoft System Application Test Library and Microsoft Tests-TestLibraries
 .Parameter installPerformanceToolkit
  Include this switch to install test Performance Test Toolkit. This includes the apps from the Test Framework and the Microsoft Business Central Performance Toolkit app
 .Parameter azureDevOps
  Include this switch if you want compile errors and test errors to surface directly in Azure Devops pipeline.
 .Parameter gitLab
  Include this switch if you want compile errors and test errors to surface directly in GitLab.
 .Parameter gitHubActions
  Include this switch if you want compile errors and test errors to surface directly in GitHubActions.
 .Parameter Failon
  Specify if you want Compilation to fail on Error or Warning
 .Parameter TreatTestFailuresAsWarnings
  Include this switch if you want to treat test failures as warnings instead of errors
 .Parameter useDevEndpoint
  Including the useDevEndpoint switch will cause the pipeline to publish apps through the development endpoint (like VS Code). This should ONLY be used when running the pipeline locally and will cause some changes in how things are done.
 .Parameter doNotBuildTests
  Include this switch to indicate that you do not want to build nor tests.
 .Parameter doNotRunTests
  Include this switch to indicate that you do not want to execute tests. Test Apps will still be published and installed, test execution can later be performed from the UI.
 .Parameter doNotRunBcptTests
  Include this switch to indicate that you do not want to execute bcpt tests. Test Apps will still be published and installed, test execution can later be performed from the UI.
 .Parameter doNotRunPageScriptingTests
  Include this switch to indicate that you do not want to execute page scripting tests.
 .Parameter doNotPerformUpgrade
  Include this switch to indicate that you do not want to perform the upgrade. This means that the previousApps are never actually published to the container.
 .Parameter doNotPublishApps
  Include this switch to indicate that you do not want to publish the app. Including this switch will also mean that upgrade won't happen and tests won't run.
 .Parameter uninstallRemovedApps
  Include this switch to indicate that you want to uninstall apps, which are included in previousApps, but not included (upgraded) in apps, i.e. removed apps
 .Parameter useCompilerFolder
  Include this switch to indicate that you want to use the compiler folder instead of creating a docker container for app compilation.
 .Parameter reUseContainer
  Including the reUseContainer switch causes pipeline to reuse the container with the given name if it exists
 .Parameter keepContainer
  Including the keepContainer switch causes the container to not be deleted after the pipeline finishes.
 .Parameter updateLaunchJson
  Specifies the name of the configuration in launch.json, which should be updated with container information to be able to start debugging right away.
 .Parameter artifactCachePath
  Artifacts Cache folder (if needed)
 .Parameter vsixFile
  Specify a URL or path to a .vsix file in order to override the .vsix file in the image with this.
  Use Get-LatestAlLanguageExtensionUrl to get latest AL Language extension from Marketplace.
  Use Get-AlLanguageExtensionFromArtifacts -artifactUrl (Get-BCArtifactUrl -select NextMajor -accept_insiderEula) to get latest insider .vsix
 .Parameter enableCodeCop
  Include this switch to include Code Cop Rules during compilation.
 .Parameter enableAppSourceCop
  Only relevant for AppSource apps. Include this switch to include AppSource Cop during compilation.
 .Parameter enableUICop
  Include this switch to include UI Cop during compilation.
 .Parameter enablePerTenantExtensionCop
  Only relevant for Per Tenant Extensions. Include this switch to include Per Tenant Extension Cop during compilation.
. Parameter enableCodeAnalyzersOnTestApps
  Include this switch to include CodeCops and other analyzers during compilation of test apps.
 .Parameter customCodeCops
  Use custom AL Cops into the container and include them, in addidtion to the default cops, during compilation.
 .Parameter useDefaultAppSourceRuleSet
  Apply the default ruleset for passing AppSource validation
 .Parameter rulesetFile
  Filename of the custom ruleset file
 .Parameter enableExternalRulesets
  Include this switch to enable external rulesets when compiling
 .Parameter preProcessorSymbols
  PreProcessorSymbols to set when compiling the app.
 .Parameter generatecrossreferences
  Include this flag to generate cross references when compiling
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the pipeline will run using the online Business Central Environment as target
 .Parameter environment
  Environment to use for the pipeline
 .Parameter escapeFromCops
  If One of the cops causes an error in an app, then show the error, recompile the app without cops and continue
 .Parameter AppSourceCopMandatoryAffixes
  Only relevant for AppSource Apps when AppSourceCop is enabled. This needs to be an array (or a string with comma separated list) of affixes used in the app.
 .Parameter AppSourceCopSupportedCountries
  Only relevant for AppSource Apps when AppSourceCop is enabled. This needs to be an array (or a string with a comma seperated list) of supported countries for this app.
 .Parameter obsoleteTagMinAllowedMajorMinor
  Only relevant for AppSource Apps. Objects that are pending obsoletion with an obsolete tag version lower than the minimum set in the AppSourceCop.json file are not allowed. (AS0105)
 .Parameter features
  Features to set when compiling the app.
 .Parameter SourceRepositoryUrl
  Repository holding the source code for the app. Will be stamped into the app manifest.
 .Parameter SourceCommit
  The commit identifier for the source code for the app. Will be stamped into the app manifest.
 .Parameter BuildBy
  Information about which product built the app. Will be stamped into the app manifest.
 .Parameter BuildUrl
  The URL for the build job, which built the app. Will be stamped into the app manifest.
 .Parameter PipelineInitialize
  Override for Pipeline Initialize
 .Parameter PipelineFinalize
  Override for Pipeline Finalize 
 .Parameter DockerPull
  Override function parameter for docker pull
 .Parameter NewBcContainer
  Override function parameter for New-BcContainer
 .Parameter SetBcContainerKeyVaultAadAppAndCertificate
  Override function parameter for Set-BcContainerKeyVaultAadAppAndCertificate
 .Parameter ImportTestToolkitToBcContainer
  Override function parameter for Import-TestToolkitToBcContainer
 .Parameter CompileAppInBcContainer
  Override function parameter for Compile-AppInBcContainer
 .Parameter CompileAppWithBcCompilerFolder
  Override function parameter for Compile-AppWithBcCompilerFolder
 .Parameter PreCompileApp
  Custom script to run before compiling an app.
  The script should accept the type of the app and a reference to the compilation parameters.
  Possible values for $appType are: app, testApp, bcptApp
  Example:
  {
    param(
        [string] $appType,
        [ref] $compilationParams
    )
    ...
    # Change the output folder based on the app type
    switch($appType) {
        "app" {
            $compilationParams.Value.appOutputFolder = "MyApps"
        }
        "testApp" {
            $compilationParams.Value.appOutputFolder = "MyTestApps"
        }
        "bcptApp" {
            $compilationParams.Value.appOutputFolder = "MyBcptApps"
        }
    }
    ...
  }
 .Parameter PostCompileApp
  Custom script to run after compiling an app.
  The script should accept the file path of the produced .app file, the type of the app, and a hashtable of the compilation parameters.
  Possible values for $appType are: app, testApp, bcptApp
  Example:
  {
    param(
        [string] $appFilePath,
        [string] $appType,
        [hashtable] $compilationParams
    )
    ...
  }
 .Parameter GetBcContainerAppInfo
  Override function parameter for Get-BcContainerAppInfo
 .Parameter PublishBcContainerApp
  Override function parameter for Publish-BcContainerApp
 .Parameter UnPublishBcContainerApp
  Override function parameter for UnPublish-BcContainerApp
 .Parameter InstallBcAppFromAppSource
  Override function parameter for Install-BcAppFromAppSource
 .Parameter SignBcContainerApp
  Override function parameter for Sign-BcContainerApp
 .Parameter BackupBcContainerDatabases
  Override function parameter for Backup-BcContainerDatabases
 .Parameter RestoreDatabasesInBcContainer
  Override function parameter for Restore-DatabasesInBcContainer
 .Parameter RunTestsInBcContainer
  Override function parameter for Run-TestsInBcContainer
 .Parameter RunBCPTTestsInBcContainer
  Override function parameter for Run-BCPTTestsInBcContainer
 .Parameter GetBcContainerAppRuntimePackage
  Override function parameter Get-BcContainerAppRuntimePackage
 .Parameter RemoveBcContainer
  Override function parameter for Remove-BcContainer
 .Parameter GetBestGenericImageName
  Override function parameter for Get-BestGenericImageName
 .Parameter GetBcContainerEventLog
  Override function parameter for Get-BcContainerEventLog
 .Parameter InstallMissingDependencies
  Override function parameter for Installing missing dependencies
 .Example
  Please visit https://www.freddysblog.com for descriptions
 .Example
  Please visit https://github.com/microsoft/bcsamples-bingmaps.pte for Per Tenant Extension example
 .Example
  Please visit https://github.com/microsoft/bcsamples-bingmaps.appsource for AppSource example

#>
function Run-AlPipeline {
Param(
    [string] $pipelineName,
    [string] $baseFolder = "",
    [string] $sharedFolder = "",
    [string] $licenseFile,
    [switch] $accept_insiderEula,
    [string] $containerName = "$($pipelineName.Replace('.','-') -replace '[^a-zA-Z0-9---]', '')-bld".ToLowerInvariant(),
    [string] $imageName = 'my',
    [switch] $enableTaskScheduler,
    [switch] $assignPremiumPlan,
    [string] $tenant = "default",
    [string] $memoryLimit,
    [string] $auth = 'UserPassword',
    [PSCredential] $credential,
    [string] $companyName = "",
    [string] $codeSignCertPfxFile = "",
    [SecureString] $codeSignCertPfxPassword = $null,
    [switch] $codeSignCertIsSelfSigned,
    [string] $keyVaultCertPfxFile = "",
    [SecureString] $keyVaultCertPfxPassword = $null,
    [string] $keyVaultClientId = "",
    $installApps = @(),
    $installTestApps = @(),
    [switch] $installOnlyReferencedApps,
    [switch] $generateDependencyArtifact,
    $previousApps = @(),
    $appFolders = @("app", "application"),
    $testFolders = @("test", "testapp"),
    $bcptTestFolders = @("bcpttest", "bcpttestapp"),
    $bcptTestSuites = @(),
    $pageScriptingTests = @(),
    $additionalCountries = @(),
    [ValidateSet('BeforeBcpTests', 'BeforePageScriptingTests', 'BeforeEachTestApp', 'BeforeEachBcptTestApp', 'BeforeEachPageScriptingTest')]
    [string[]] $restoreDatabases = @(),
    [string] $appVersion = "",
    [int] $appBuild = 0,
    [int] $appRevision = 0,
    [string] $applicationInsightsKey,
    [string] $applicationInsightsConnectionString,
    [string] $buildOutputFile = "",
    [string] $containerEventLogFile = "",
    [string] $testResultsFile = "TestResults.xml",
    [string] $bcptTestResultsFile = "bcptTestResults.json",
    [string] $pageScriptingTestResultsFile = "PageScriptingTestResults.xml",
    [string] $pageScriptingTestResultsFolder = "PageScriptingTestResults",
    [Parameter(Mandatory=$false)]
    [ValidateSet('XUnit','JUnit')]
    [string] $testResultsFormat = "JUnit",
    [string] $packagesFolder = ".packages",
    [string] $outputFolder = ".output",
    [string] $artifact = "///us/Current",
    [string] $useGenericImage = "",
    [string] $buildArtifactFolder = "",
    [switch] $createRuntimePackages,
    [switch] $installTestRunner,
    [switch] $installTestFramework,
    [switch] $installTestLibraries,
    [switch] $installPerformanceToolkit,
    [switch] $CopySymbolsFromContainer,
    [switch] $UpdateDependencies,
    [switch] $azureDevOps = $bcContainerHelperConfig.IsAzureDevOps,
    [switch] $gitLab = $bcContainerHelperConfig.IsGitLab,
    [switch] $gitHubActions = $bcContainerHelperConfig.IsGitHubActions,
    [ValidateSet('none','error','warning')]
    [string] $failOn = "none",
    [switch] $treatTestFailuresAsWarnings,
    [switch] $useDevEndpoint,
    [switch] $doNotBuildTests,
    [switch] $doNotRunTests,
    [switch] $doNotRunBcptTests,
    [switch] $doNotRunPageScriptingTests,
    [switch] $doNotPerformUpgrade,
    [switch] $doNotPublishApps,
    [switch] $uninstallRemovedApps,
    [switch] $useCompilerFolder = $bcContainerHelperConfig.useCompilerFolder,
    [switch] $reUseContainer,
    [switch] $keepContainer,
    [string] $updateLaunchJson = "",
    [string] $artifactCachePath = "",
    [string] $vsixFile = "",
    [switch] $enableCodeCop,
    [switch] $enableAppSourceCop,
    [switch] $enableUICop,
    [switch] $enablePerTenantExtensionCop,
    [switch] $enableCodeAnalyzersOnTestApps,
    $customCodeCops = @(),
    [switch] $useDefaultAppSourceRuleSet,
    [string] $rulesetFile = "",
    [switch] $generateErrorLog,
    [switch] $enableExternalRulesets,
    [string[]] $preProcessorSymbols = @(),
    [switch] $generatecrossreferences,
    [switch] $escapeFromCops,
    [Hashtable] $bcAuthContext,
    [string] $environment,
    $AppSourceCopMandatoryAffixes = @(),
    $AppSourceCopSupportedCountries = @(),
    [string] $obsoleteTagMinAllowedMajorMinor = "",
    [string[]] $features = @(),
    [string] $sourceRepositoryUrl = '',
    [string] $sourceCommit = '',
    [string] $buildBy = "BcContainerHelper,$BcContainerHelperVersion",
    [string] $buildUrl = '',
    [scriptblock] $PipelineInitialize,
    [scriptblock] $DockerPull,
    [scriptblock] $NewBcContainer,
    [scriptblock] $SetBcContainerKeyVaultAadAppAndCertificate,
    [scriptblock] $ImportTestToolkitToBcContainer,
    [scriptblock] $CompileAppInBcContainer,
    [scriptblock] $CompileAppWithBcCompilerFolder,
    [scriptblock] $PreCompileApp,
    [scriptblock] $PostCompileApp,
    [scriptblock] $GetBcContainerAppInfo,
    [scriptblock] $PublishBcContainerApp,
    [scriptblock] $UnPublishBcContainerApp,
    [scriptblock] $InstallBcAppFromAppSource,
    [scriptblock] $SignBcContainerApp,
    [scriptblock] $ImportTestDataInBcContainer,
    [scriptblock] $BackupBcContainerDatabases,
    [scriptblock] $RestoreDatabasesInBcContainer,
    [scriptblock] $RunTestsInBcContainer,
    [scriptblock] $RunBCPTTestsInBcContainer,
    [scriptblock] $GetBcContainerAppRuntimePackage,
    [scriptblock] $RemoveBcContainer,
    [scriptblock] $GetBestGenericImageName,
    [scriptblock] $GetBcContainerEventLog,
    [scriptblock] $InstallMissingDependencies,
    [scriptblock] $PipelineFinalize
)

function CheckRelativePath([string] $baseFolder, [string] $sharedFolder, $path, $name) {
    if ($path -and $path -notlike 'https://*') {
        if (-not [System.IO.Path]::IsPathRooted($path)) {
            if (Test-Path -Path (Join-Path $baseFolder $path)) {
                $path = Join-Path $baseFolder $path -Resolve
            }
            else {
                $path = Join-Path $baseFolder $path
            }
        }
        else {
            if (!(($path -like "$($baseFolder)*") -or (($sharedFolder) -and ($path -like "$($sharedFolder)*")))) {
                if ($sharedFolder) {
                    throw "$name is ($path) must be a subfolder to baseFolder ($baseFolder) or sharedFolder ($sharedFolder)"
                }
                else {
                    throw "$name is ($path) must be a subfolder to baseFolder ($baseFolder)"
                }
            }
        }
    }
    $path
}

function UpdateLaunchJson {
    Param(
        [string] $launchJsonFile,
        [System.Collections.Specialized.OrderedDictionary] $launchSettings
    )

    if (Test-Path $launchJsonFile) {
        Write-Host "Modifying $launchJsonFile"
        $launchJson = [System.IO.File]::ReadAllLines($LaunchJsonFile) | ConvertFrom-Json
    }
    else {
        Write-Host "Creating $launchJsonFile"
        $dir = [System.IO.Path]::GetDirectoryName($launchJsonFile)
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory | Out-Null
        }
        $launchJson = @{ "version" = "0.2.0"; "configurations" = @() } | ConvertTo-Json | ConvertFrom-Json
    }
    $launchSettings | ConvertTo-Json | Out-Host
    $oldSettings = $launchJson.configurations | Where-Object { $_.name -eq $launchsettings.name }
    if ($oldSettings) {
        $oldSettings.PSObject.Properties | ForEach-Object {
            $prop = $_.Name
            if (!($launchSettings.Keys | Where-Object { $_ -eq $prop } )) {
                $launchSettings += @{ "$prop" = $oldSettings."$prop" }
            }
        }
    }
    $launchJson.configurations = @($launchJson.configurations | Where-Object { $_.name -ne $launchsettings.name })
    $launchJson.configurations += $launchSettings
    $launchJson | ConvertTo-Json -Depth 10 | Set-Content $launchJsonFile

}

function GetInstalledApps {
    Param(
        [hashtable] $bcAuthContext,
        [string] $environment,
        [bool] $useCompilerFolder,
        [string] $packagesFolder,
        [bool] $filesOnly
    )
    if ($bcAuthContext -and $environment -and $environment -notlike ('https://*')) {
        # PublishedAs is either "Global", " PTE" or " Dev" (with leading space)
        $installedExtensions = Get-BcInstalledExtensions -bcAuthContext $bcAuthContext -environment $environment
        $installedApps = $installedExtensions | Where-Object { $_.IsInstalled } | ForEach-Object {
            @{ "AppId" = $_.id; "Publisher" = $_.publisher; "Name" = $_.displayName; "Version" = [System.Version]::new($_.VersionMajor,$_.VersionMinor,$_.VersionBuild,$_.VersionRevision) }
        }
    }
    elseif ($useCompilerFolder) {
        $compilerFolder = (GetCompilerFolder)
        $existingAppFiles = @(Get-ChildItem -Path (Join-Path $packagesFolder '*.app') | Select-Object -ExpandProperty FullName)
        $installedApps = @(GetAppInfo -AppFiles $existingAppFiles -compilerFolder $compilerFolder -cacheAppinfoPath (Join-Path $packagesFolder 'cache_AppInfo.json'))
        $compilerFolderAppFiles = @(Get-ChildItem -Path (Join-Path $compilerFolder 'symbols/*.app') | Select-Object -ExpandProperty FullName)
        $installedApps += @(GetAppInfo -AppFiles $compilerFolderAppFiles -compilerFolder $compilerFolder -cacheAppinfoPath (Join-Path $compilerFolder 'symbols/cache_AppInfo.json'))
    }
    elseif ($filesOnly) {
        # Make sure container has been created
        GetBuildContainer | Out-Null
        $installedApps = Get-ChildItem -Path (Join-Path $packagesFolder '*.app') | ForEach-Object {
            $appJson = Get-AppJsonFromAppFile -appFile $_.FullName
            return @{
                "AppId"                 = $appJson.id
                "Name"                  = $appJson.name
                "Publisher"             = $appJson.publisher
                "Version"               = $appJson.version
            }
        }
    }
    else {
        $Parameters = @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "tenantSpecificProperties" = $true
        }
        $installedApps = @(Invoke-Command -ScriptBlock $GetBcContainerAppInfo -ArgumentList $Parameters | Where-Object { $_.IsInstalled })
    }
    Write-GroupStart -Message "Installed Apps"
    $installedApps | ForEach-Object {
        Write-Host "- $($_.AppId):$($_.Name)"
        return @{ "Id" = "$($_.AppId)"; "Name" = "$($_.Name)"; "Publisher" = "$($_.Publisher)"; "Version" = "$($_.Version)" }
    }
    Write-GroupEnd
}

$script:existingContainerName = ''
$script:existingCompilerFolder = ''

function PullGenericImage {
    Measure-Command {
        Write-Host -ForegroundColor Yellow @'

  _____       _ _ _                                          _        _
 |  __ \     | | (_)                                        (_)      (_)
 | |__) |   _| | |_ _ __   __ _    __ _  ___ _ __   ___ _ __ _  ___   _ _ __ ___   __ _  __ _  ___
 |  ___/ | | | | | | '_ \ / _` |  / _` |/ _ \ '_ \ / _ \ '__| |/ __| | | '_ ` _ \ / _` |/ _` |/ _ \
 | |   | |_| | | | | | | | (_| | | (_| |  __/ | | |  __/ |  | | (__  | | | | | | | (_| | (_| |  __/
 |_|    \__,_|_|_|_|_| |_|\__, |  \__, |\___|_| |_|\___|_|  |_|\___| |_|_| |_| |_|\__,_|\__, |\___|
                           __/ |   __/ |                                                 __/ |
                          |___/   |___/                                                 |___/

'@
        Write-PSCallStack
        if (!$useGenericImage) {
            $Parameters = @{
                "filesOnly" = $filesOnly
            }
            $useGenericImage = Invoke-Command -ScriptBlock $GetBestGenericImageName -ArgumentList $Parameters
        }
        Write-Host "Pulling $useGenericImage"
        Invoke-Command -ScriptBlock $DockerPull -ArgumentList $useGenericImage
    } | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPulling generic image took $([int]$_.TotalSeconds) seconds" }
}

# Create build container and return containerName
function GetBuildContainer {
    if (!$createContainer -or $script:existingContainerName) {
        # Either we are not using a container (return blank)
        # Or we have a container (return existing)
        # Or we should not create a new (return blank)
        return $script:existingContainerName
    }

    PullGenericImage

    Measure-Command {
        Write-Host -ForegroundColor Yellow @'

   _____                _   _                _____            _        _
  / ____|              | | (_)              / ____|          | |      (_)
 | |     _ __ ___  __ _| |_ _ _ __   __ _  | |     ___  _ __ | |_ __ _ _ _ __   ___ _ __
 | |    | '__/ _ \/ _` | __| | '_ \ / _` | | |    / _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | |____| | |  __/ (_| | |_| | | | | (_| | | |___| (_) | | | | || (_| | | | | |  __/ |
  \_____|_|  \___|\__,_|\__|_|_| |_|\__, |  \_____\___/|_| |_|\__\__,_|_|_| |_|\___|_|
                                     __/ |
                                    |___/

'@
        Write-PSCallStack
        $Parameters = @{}
        $useExistingContainer = $false
        if ($createContainer -and ($filesOnly -or !$doNotPublishApps)) {
            # If we are going to build using a filesOnly container or we are going to publish apps, we need a container
            if (Test-BcContainer -containerName $containerName) {
                if ($bcAuthContext) {
                    if ($artifactUrl -eq (Get-BcContainerArtifactUrl -containerName $containerName)) {
                        $useExistingContainer = ((Get-BcContainerPath -containerName $containerName -path $baseFolder) -ne "")
                    }
                }
                elseif ($reUseContainer) {
                    $containerArtifactUrl = Get-BcContainerArtifactUrl -containerName $containerName
                    if ($artifactUrl -ne $containerArtifactUrl) {
                        Write-Host "WARNING: Reusing a container based on $($containerArtifactUrl.Split('?')[0]), should be $($ArtifactUrl.Split('?')[0])"
                    }
                    if ((Get-BcContainerPath -containerName $containerName -path $baseFolder) -eq "") {
                        throw "$baseFolder is not shared with container $containerName"
                    }
                    $useExistingContainer = $true
                }
            }
        }

        if ($useExistingContainer) {
            Write-Host "Reusing existing docker container"
        }
        else {
            Write-Host "Creaing docker container"
            $Parameters += @{
                "FilesOnly" = $filesOnly
            }

            if ($imageName)   { $Parameters += @{ "imageName"   = $imageName } }
            if ($memoryLimit) { $Parameters += @{ "memoryLimit" = $memoryLimit } }

            $Parameters += @{
                "accept_eula" = $true
                "accept_insiderEula" = $accept_insiderEula
                "containerName" = $containerName
                "artifactUrl" = $artifactUrl
                "useGenericImage" = $useGenericImage
                "Credential" = $credential
                "auth" = $auth
                "vsixFile" = $vsixFile
                "updateHosts" = !$IsInsideContainer
                "licenseFile" = $licenseFile
                "EnableTaskScheduler" = $enableTaskScheduler
                "AssignPremiumPlan" = $assignPremiumPlan
                "additionalParameters" = @("--volume ""$($baseFolder):c:\sources""")
            }
            if ($sharedFolder) {
                $Parameters.additionalParameters += @("--volume ""$($sharedFolder):c:\shared""")
            }
            Invoke-Command -ScriptBlock $NewBcContainer -ArgumentList $Parameters

            if ($createContainer -and -not $bcAuthContext) {
                if ($keyVaultCertPfxFile -and $KeyVaultClientId -and $keyVaultCertPfxPassword) {
                    $Parameters = @{
                        "containerName" = $containerName
                        "pfxFile" = $keyVaultCertPfxFile
                        "pfxPassword" = $keyVaultCertPfxPassword
                        "clientId" = $keyVaultClientId
                    }
                    Invoke-Command -ScriptBlock $SetBcContainerKeyVaultAadAppAndCertificate -ArgumentList $Parameters
                }
            }
        }

        if ($tenant -ne 'default' -and -not (Get-BcContainerTenants -containerName $containerName | Where-Object { $_.id -eq $tenant })) {

            $Parameters = @{
                "containerName" = $containerName
                "tenantId" = $tenant
            }
            New-BcContainerTenant @Parameters

            $Parameters = @{
                "containerName" = $containerName
                "tenant" = $tenant
                "credential" = $credential
                "permissionsetId" = "SUPER"
                "ChangePasswordAtNextLogOn" = $false
                "assignPremiumPlan" = $assignPremiumPlan
            }
            New-BcContainerBcUser @Parameters

            $tenantApps = Get-BcContainerAppInfo -containerName $containerName -tenant $tenant -tenantSpecificProperties -sort DependenciesFirst
            Get-BcContainerAppInfo -containerName $containerName -tenant "default" -tenantSpecificProperties -sort DependenciesFirst | Where-Object { $_.IsInstalled } | ForEach-Object {
                $name = $_.Name
                $version = $_.Version
                $tenantApp = $tenantApps | Where-Object { $_.Name -eq $name -and $_.Version -eq $version }
                if ($tenantApp.SyncState -eq "NotSynced" -or $tenantApp.SyncState -eq 3) {
                    Sync-BcContainerApp -containerName $containerName -tenant $tenant -appName $Name -appVersion $Version -Mode ForceSync -Force
                }
                if (-not $tenantApp.IsInstalled) {
                    Install-BcContainerApp -containerName $containerName -tenant $tenant -appName $_.Name -appVersion $_.Version
                }
            }
        }
        if ($CopySymbolsFromContainer) {
            $containerSymbolsFolder = Get-BcContainerPath -containerName $containerName -path $packagesFolder
            if ("$containerSymbolsFolder" -eq "") {
                throw "The appSymbolsFolder ($appSymbolsFolder) is not shared with the container."
            }
            CopySymbolsFromContainer -containerName $containerName -containerSymbolsFolder $containerSymbolsFolder
            $CopySymbolsFromContainer = $false
        }
    } | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCreating Container took $([int]$_.TotalSeconds) seconds" }
    $script:existingContainerName = $containerName
    return $script:existingContainerName
}


function RemoveBuildContainer {
    if ($script:existingContainerName) {
        $Parameters = @{
            "containerName" = $script:existingContainerName
        }
        Invoke-Command -ScriptBlock $RemoveBcContainer -ArgumentList $Parameters
        $script:existingContainerName = ''
    }
}

# Create compilerFolder and return path
function GetCompilerFolder {
    if (!$useCompilerFolder -or $script:existingCompilerFolder) {
        # Either we are not using CompilerFolder (return blank)
        # Or we have a compilerfolder (return existing)
        return $script:existingCompilerFolder
    }

    Measure-Command {
        Write-Host -ForegroundColor Yellow @'

   _____                _   _                _____                      _ _           ______    _     _
  / ____|              | | (_)              / ____|                    (_) |         |  ____|  | |   | |
 | |     _ __ ___  __ _| |_ _ _ __   __ _  | |     ___  _ __ ___  _ __  _| | ___ _ __| |__ ___ | | __| | ___ _ __
 | |    | '__/ _ \/ _` | __| | '_ \ / _` | | |    / _ \| '_ ` _ \| '_ \| | |/ _ \ '__|  __/ _ \| |/ _` |/ _ \ '__|
 | |____| | |  __/ (_| | |_| | | | | (_| | | |___| (_) | | | | | | |_) | | |  __/ |  | | | (_) | | (_| |  __/ |
  \_____|_|  \___|\__,_|\__|_|_| |_|\__, |  \_____\___/|_| |_| |_| .__/|_|_|\___|_|  |_|  \___/|_|\__,_|\___|_|
                                     __/ |                       | |
                                    |___/                        |_|
'@
        Write-PSCallStack
        Write-Host "Creating CompilerFolder '$artifactUrl'"
        $compilerFolder = New-BcCompilerFolder `
            -artifactUrl $artifactUrl `
            -cacheFolder $artifactCachePath `
            -vsixFile $vsixFile `
            -containerName $containerName
        Write-Host "CompilerFolder $compilerFolder created"
    } | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCreating CompilerFolder took $([int]$_.TotalSeconds) seconds" }
    $script:existingCompilerFolder = $compilerFolder
    return $script:existingCompilerFolder
}

function RemoveCompilerFolder {
    if ($script:existingCompilerFolder) {
        Remove-BcCompilerFolder -compilerFolder $script:existingCompilerFolder
        $script:existingCompilerFolder = ''
    }
}


$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

if ($PipelineInitialize) {
    Invoke-Command -ScriptBlock $PipelineInitialize
}

$warningsToShow = @()

if (!$baseFolder -or !(Test-Path $baseFolder -PathType Container)) {
    throw "baseFolder must be an existing folder"
}
if ($sharedFolder -and !(Test-Path $sharedFolder -PathType Container)) {
    throw "If sharedFolder is specified, it must be an existing folder"
}

if($keepContainer -and !$credential) {
    # If keepContainer is specified, credentials must also be specified, as otherwise the container will be created with a random password and there will be no way to access it.
    throw "If keepContainer is specified, you must also specify credentials"
}

if(!$credential) {
    # Create a random password to use, as the container will not be kept after the pipeline finishes.
    $password = GetRandomPassword
    $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}

if ($memoryLimit -eq "") {
    $memoryLimit = "8G"
}

if ($installApps                    -is [String]) { $installApps = @($installApps.Split(',').Trim() | Where-Object { $_ }) }
if ($installTestApps                -is [String]) { $installTestApps = @($installTestApps.Split(',').Trim() | Where-Object { $_ }) }
if ($previousApps                   -is [String]) { $previousApps = @($previousApps.Split(',').Trim() | Where-Object { $_ }) }
if ($appFolders                     -is [String]) { $appFolders = @($appFolders.Split(',').Trim()  | Where-Object { $_ }) }
if ($testFolders                    -is [String]) { $testFolders = @($testFolders.Split(',').Trim() | Where-Object { $_ }) }
if ($bcptTestFolders                -is [String]) { $bcptTestFolders = @($bcptTestFolders.Split(',').Trim() | Where-Object { $_ }) }
if ($pageScriptingTests             -is [String]) { $pageScriptingTests = @($pageScriptingTests.Split(',').Trim() | Where-Object { $_ }) }
if ($additionalCountries            -is [String]) { $additionalCountries = @($additionalCountries.Split(',').Trim() | Where-Object { $_ }) }
if ($AppSourceCopMandatoryAffixes   -is [String]) { $AppSourceCopMandatoryAffixes = @($AppSourceCopMandatoryAffixes.Split(',').Trim() | Where-Object { $_ }) }
if ($AppSourceCopSupportedCountries -is [String]) { $AppSourceCopSupportedCountries = @($AppSourceCopSupportedCountries.Split(',').Trim() | Where-Object { $_ }) }
if ($customCodeCops                 -is [String]) { $customCodeCops = @($customCodeCops.Split(',').Trim() | Where-Object { $_ }) }
if ($restoreDatabases               -is [string]) { $restoreDatabases = @($restoreDatabases.Split(',').Trim() | Where-Object { $_ }) }

$appFolders  = @($appFolders  | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "appFolders" } | Where-Object { Test-Path $_ } )
$testFolders = @($testFolders | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "testFolders" } | Where-Object { Test-Path $_ } )
$bcptTestFolders = @($bcptTestFolders | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "bcptTestFolders" } | Where-Object { Test-Path $_ } )
$pageScriptingTests = @($pageScriptingTests | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "pageScriptingTests" } | Where-Object { Test-Path $_ } | ForEach-Object { if (Test-Path -Path $_ -PathType Container) { return (Join-Path $_ '*.yml') } else { return $_ } } )
$customCodeCops = @($customCodeCops | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "customCodeCops" } | Where-Object { $_ -like 'https://*' -or (Test-Path $_) } )
$buildOutputFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $buildOutputFile -name "buildOutputFile"
$containerEventLogFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $containerEventLogFile -name "containerEventLogFile"
$testResultsFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $testResultsFile -name "testResultsFile"
$bcptTestResultsFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $bcptTestResultsFile -name "bcptTestResultsFile"
$pageScriptingTestResultsFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $pageScriptingTestResultsFile -name "pageScriptingTestResultsFile"
$pageScriptingTestResultsFolder = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $pageScriptingTestResultsFolder -name "pageScriptingTestResultsFolder"
$rulesetFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $rulesetFile -name "rulesetFile"

$restoreDatabases | ForEach-Object {
    if ($_ -notin @("BeforeBcpTests", "BeforeEachTestApp", "BeforeEachBcptTestApp", "BeforeEachPageScriptingTest", "BeforePageScriptingTests")) {
        throw "restoreDatabases must be one of the following values: BeforeBcpTests, BeforeEachTestApp, BeforeEachBcptTestApp, BeforePageScriptingTests, BeforeEachPageScriptingTest"
    }
}
$containerEventLogFile,$buildOutputFile,$testResultsFile,$bcptTestResultsFile | ForEach-Object {
    if ($_ -and (Test-Path $_)) {
        Remove-Item -Path $_ -Force
    }
}
if ($pageScriptingTestResultsFolder -and (Test-Path $pageScriptingTestResultsFolder)) {
    Remove-Item -Path $pageScriptingTestResultsFolder -Recurse -Force
    New-Item -ItemType Directory -Path $pageScriptingTestResultsFolder | Out-Null
}
if ($pageScriptingTestResultsFile -and (Test-Path $pageScriptingTestResultsFile)) {
    Remove-Item -Path $pageScriptingTestResultsFile -Force
}

$addBcptTestSuites = $true
if ($bcptTestSuites) {
    $addBcptTestSuites = $false
}
if ($bcptTestFolders) {
    $bcptTestFolders | ForEach-Object {
        if (-not (Test-Path (Join-Path $_ "bcptSuite.json"))) {
            throw "no bcptsuite.json found in bcpt test folder $_"
        }
        if ($addBcptTestSuites) {
            $bcptTestSuites += @((Join-Path $_ "bcptSuite.json"))
        }
    }
}

$artifactUrl = ""
$filesOnly = $false
if ($bcAuthContext) {
    if ("$environment" -eq "") {
        throw "When specifying bcAuthContext, you also have to specify the name of the pre-setup online environment to use."
    }
    if ($additionalCountries) {
        throw "You cannot specify additional countries when using an online environment."
    }
    if ($uninstallRemovedApps) {
        Write-Host -ForegroundColor Yellow "Uninstalling removed apps from online environments are not supported"
        $uninstallRemovedApps = $false
    }
    if (!$doNotRunBcptTests -and $bcptTestSuites) {
        throw "BCPT Tests are not supported on cloud pipelines yet!"
    }
    if (!$doNotRunPageScriptingTests -and $pageScriptingTests -and $pageScriptingTestResultsFolder -and $pageScriptingTestResultsFile) {
        throw "Page scripting Tests are not supported on cloud pipelines yet!"
    }

    if ($environment -notlike ('https://*')) {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.name -eq $environment -and $_.type -eq "Sandbox" }
        if (!($bcEnvironment)) {
            throw "Environment $environment doesn't exist in the current context or it is not a Sandbox environment."
        }
        $parameters = @{
            bcAuthContext = $bcAuthContext
            environment = $environment
        }
        $bcBaseApp = Get-BcPublishedApps @Parameters | Where-Object { $_.Name -eq "Base Application" -and $_.state -eq "installed" }
        $artifactUrl = Get-BCArtifactUrl -type Sandbox -country $bcEnvironment.countryCode -version $bcBaseApp.Version -select Closest
    }
    $filesOnly = $true
}
elseif (!$doNotRunPageScriptingTests -and $pageScriptingTests -and $pageScriptingTestResultsFolder -and $pageScriptingTestResultsFile) {
    $npmVersion = pwsh -command { npm --version }
    if ($? -ne "True") {
        throw "npm isn't installed - cannot run page scripting tests"
    }
    Write-Host "npm version $npmVersion is installed"
}

if ($updateLaunchJson) {
    if (!$useDevEndpoint) {
        throw "UpdateLaunchJson cannot be specified if not using DevEndpoint"
    }
}

if ($useCompilerFolder -or $filesOnly -or !$useDevEndpoint) {
    $packagesFolder = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $packagesFolder -name "packagesFolder"
    if (!($bcContainerHelperConfig.doNotRemovePackagesFolderIfExists)) {
        if (Test-Path $packagesFolder) {
            Remove-Item $packagesFolder -Recurse -Force
        }
    }
    New-Item $packagesFolder -ItemType Directory -Force | Out-Null 
}

if ($useDevEndpoint) {
    $outputFolder = ""
}
else {
    $outputFolder = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $outputFolder -name "outputFolder"
    if (Test-Path $outputFolder) {
        Remove-Item $outputFolder -Recurse -Force
    }
}

if ($buildArtifactFolder) {
    if (!(Test-Path $buildArtifactFolder)) {
        New-Item $buildArtifactFolder -ItemType Directory | Out-Null
    }
}
if ($generateDependencyArtifact) {
    $dependenciesFolder = Join-Path $buildArtifactFolder "Dependencies"
    if (!(Test-Path $dependenciesFolder)) {
        New-Item -ItemType Directory -Path $dependenciesFolder | Out-Null
    }
}

if (!($appFolders)) {
    Write-Host "WARNING: No app folders found"
}

if ($useDevEndpoint) {
    $additionalCountries = @()
}

if ("$artifact" -eq "" -or "$artifactUrl" -ne "") {
    # Do nothing
}
elseif ($artifact -like "https://*") {
    $artifactUrl = $artifact
}
else {
    $segments = "$artifact/////".Split('/')
    $storageAccount = $segments[0];
    $type = $segments[1]; if ($type -eq "") { $type = 'Sandbox' }
    $version = $segments[2]
    $country = $segments[3]; if ($country -eq "") { $country = "us" }
    $select = $segments[4]; if ($select -eq "") { $select = "latest" }

    Write-Host "Determining artifacts to use"
    $minsto = $storageAccount
    $minsel = $select
    if ($additionalCountries) {
        $minver = $null
        @($country)+$additionalCountries | ForEach-Object {
            $url = Get-BCArtifactUrl -storageAccount $storageAccount -type $type -version $version -country $_.Trim() -select $select -accept_insiderEula:$accept_insiderEula | Select-Object -First 1
            Write-Host "Found $($url.Split('?')[0])"
            if ($url) {
                $ver = [Version]$url.Split('/')[4]
                if ($minver -eq $null -or $ver -lt $minver) {
                    $minver = $ver
                    $minsto = (ReplaceCDN -sourceUrl $url.Split('/')[2] -useBlobUrl).Split('.')[0]
                    $minsel = "Latest"
                }
            }
        }
        if ($minver -eq $null) {
            throw "Unable to locate artifacts"
        }
        $version = $minver.ToString()
    }
    $artifactUrl = Get-BCArtifactUrl -storageAccount $minsto -type $type -version $version -country $country -select $minsel -accept_insiderEula:$accept_insiderEula | Select-Object -First 1
    if (!($artifactUrl)) {
        throw "Unable to locate artifacts"
    }
}

Write-Host -ForegroundColor yellow $artifactUrl

$escapeFromCops = $escapeFromCops -and ($enableCodeCop -or $enableAppSourceCop -or $enableUICop -or $enablePerTenantExtensionCop)

Write-GroupStart -Message "Parameters"
Write-Host -ForegroundColor Yellow @'
  _____                               _
 |  __ \                             | |
 | |__) |_ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___
 |  ___/ _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
 | |  | (_| | | | (_| | | | | | |  __/ |_  __/ |  \__ \
 |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/

'@
Write-Host -NoNewLine -ForegroundColor Yellow "Pipeline name                   "; Write-Host $pipelineName
Write-Host -NoNewLine -ForegroundColor Yellow "Container name                  "; Write-Host $containerName
Write-Host -NoNewLine -ForegroundColor Yellow "Image name                      "; Write-Host $imageName
Write-Host -NoNewLine -ForegroundColor Yellow "ArtifactUrl                     "; Write-Host $artifactUrl.Split('?')[0]
Write-Host -NoNewLine -ForegroundColor Yellow "BcAuthContext                   "; if ($bcauthcontext) { Write-Host "Specified" } else { Write-Host "Not Specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "Environment                     "; Write-Host $environment
Write-Host -NoNewLine -ForegroundColor Yellow "ReUseContainer                  "; Write-Host $reUseContainer
Write-Host -NoNewLine -ForegroundColor Yellow "KeepContainer                   "; Write-Host $keepContainer
Write-Host -NoNewLine -ForegroundColor Yellow "useCompilerFolder               "; Write-Host $useCompilerFolder
Write-Host -NoNewLine -ForegroundColor Yellow "artifactCachePath               "; Write-Host $artifactCachePath
Write-Host -NoNewLine -ForegroundColor Yellow "useDevEndpoint                  "; Write-Host $useDevEndpoint
Write-Host -NoNewLine -ForegroundColor Yellow "Auth                            "; Write-Host $auth
Write-Host -NoNewLine -ForegroundColor Yellow "CompanyName                     "; Write-Host $companyName
Write-Host -NoNewLine -ForegroundColor Yellow "MemoryLimit                     "; Write-Host $memoryLimit
Write-Host -NoNewLine -ForegroundColor Yellow "FailOn                          "; Write-Host $failOn
Write-Host -NoNewLine -ForegroundColor Yellow "TreatTestFailuresAsWarnings     "; Write-Host $treatTestFailuresAsWarnings
Write-Host -NoNewLine -ForegroundColor Yellow "Enable Task Scheduler           "; Write-Host $enableTaskScheduler
Write-Host -NoNewLine -ForegroundColor Yellow "Assign Premium Plan             "; Write-Host $assignPremiumPlan
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Runner             "; Write-Host $installTestRunner
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Framework          "; Write-Host $installTestFramework
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Libraries          "; Write-Host $installTestLibraries
Write-Host -NoNewLine -ForegroundColor Yellow "Install Perf. Toolkit           "; Write-Host $installPerformanceToolkit
Write-Host -NoNewLine -ForegroundColor Yellow "InstallOnlyReferencedApps       "; Write-Host $installOnlyReferencedApps
Write-Host -NoNewLine -ForegroundColor Yellow "generateDependencyArtifact      "; Write-Host $generateDependencyArtifact
Write-Host -NoNewLine -ForegroundColor Yellow "CopySymbolsFromContainer        "; Write-Host $CopySymbolsFromContainer
Write-Host -NoNewLine -ForegroundColor Yellow "enableCodeCop                   "; Write-Host $enableCodeCop
Write-Host -NoNewLine -ForegroundColor Yellow "enableAppSourceCop              "; Write-Host $enableAppSourceCop
Write-Host -NoNewLine -ForegroundColor Yellow "enableUICop                     "; Write-Host $enableUICop
Write-Host -NoNewLine -ForegroundColor Yellow "enablePerTenantExtensionCop     "; Write-Host $enablePerTenantExtensionCop
Write-Host -NoNewLine -ForegroundColor Yellow "enableCodeAnalyzersOnTestApps   "; Write-Host $enableCodeAnalyzersOnTestApps
Write-Host -NoNewLine -ForegroundColor Yellow "doNotPerformUpgrade             "; Write-Host $doNotPerformUpgrade
Write-Host -NoNewLine -ForegroundColor Yellow "doNotPublishApps                "; Write-Host $doNotPublishApps
Write-Host -NoNewLine -ForegroundColor Yellow "uninstallRemovedApps            "; Write-Host $uninstallRemovedApps
Write-Host -NoNewLine -ForegroundColor Yellow "escapeFromCops                  "; Write-Host $escapeFromCops
Write-Host -NoNewLine -ForegroundColor Yellow "doNotBuildTests                 "; Write-Host $doNotBuildTests
Write-Host -NoNewLine -ForegroundColor Yellow "doNotRunTests                   "; Write-Host $doNotRunTests
Write-Host -NoNewLine -ForegroundColor Yellow "doNotRunBcptTests               "; Write-Host $doNotRunBcptTests
Write-Host -NoNewLine -ForegroundColor Yellow "doNotRunPageScriptingTests      "; Write-Host $doNotRunPageScriptingTests
Write-Host -NoNewLine -ForegroundColor Yellow "useDefaultAppSourceRuleSet      "; Write-Host $useDefaultAppSourceRuleSet
Write-Host -NoNewLine -ForegroundColor Yellow "rulesetFile                     "; Write-Host $rulesetFile
Write-Host -NoNewLine -ForegroundColor Yellow "generateErrorLog                "; Write-Host $generateErrorLog
Write-Host -NoNewLine -ForegroundColor Yellow "enableExternalRulesets          "; Write-Host $enableExternalRulesets
Write-Host -NoNewLine -ForegroundColor Yellow "azureDevOps                     "; Write-Host $azureDevOps
Write-Host -NoNewLine -ForegroundColor Yellow "gitLab                          "; Write-Host $gitLab
Write-Host -NoNewLine -ForegroundColor Yellow "gitHubActions                   "; Write-Host $gitHubActions
Write-Host -NoNewLine -ForegroundColor Yellow "vsixFile                        "; Write-Host $vsixFile
Write-Host -NoNewLine -ForegroundColor Yellow "License file                    "; if ($licenseFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertPfxFile             "; if ($codeSignCertPfxFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertPfxPassword         "; if ($codeSignCertPfxPassword) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertIsSelfSigned        "; Write-Host $codeSignCertIsSelfSigned.ToString()
Write-Host -NoNewLine -ForegroundColor Yellow "KeyVaultCertPfxFile             "; if ($keyVaultCertPfxFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "KeyVaultCertPfxPassword         "; if ($keyVaultCertPfxPassword) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "KeyVaultClientId                "; Write-Host $keyVaultClientId
Write-Host -NoNewLine -ForegroundColor Yellow "BuildOutputFile                 "; Write-Host $buildOutputFile
Write-Host -NoNewLine -ForegroundColor Yellow "ContainerEventLogFile           "; Write-Host $containerEventLogFile
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFile                 "; Write-Host $testResultsFile
Write-Host -NoNewLine -ForegroundColor Yellow "BcptTestResultsFile             "; Write-Host $bcptTestResultsFile
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFormat               "; Write-Host $testResultsFormat
Write-Host -NoNewLine -ForegroundColor Yellow "AdditionalCountries             "; Write-Host ([string]::Join(',',$additionalCountries))
Write-Host -NoNewLine -ForegroundColor Yellow "PackagesFolder                  "; Write-Host $packagesFolder
Write-Host -NoNewLine -ForegroundColor Yellow "OutputFolder                    "; Write-Host $outputFolder
Write-Host -NoNewLine -ForegroundColor Yellow "BuildArtifactFolder             "; Write-Host $buildArtifactFolder
Write-Host -NoNewLine -ForegroundColor Yellow "CreateRuntimePackages           "; Write-Host $createRuntimePackages
Write-Host -NoNewLine -ForegroundColor Yellow "AppVersion                      "; Write-Host $appVersion
Write-Host -NoNewLine -ForegroundColor Yellow "AppBuild                        "; Write-Host $appBuild
Write-Host -NoNewLine -ForegroundColor Yellow "AppRevision                     "; Write-Host $appRevision
Write-Host -NoNewLine -ForegroundColor Yellow "SourceRepositoryUrl             "; Write-Host $sourceRepositoryUrl
Write-Host -NoNewLine -ForegroundColor Yellow "SourceCommit                    "; Write-Host $sourceCommit
Write-Host -NoNewLine -ForegroundColor Yellow "BuildBy                         "; Write-Host $buildBy
Write-Host -NoNewLine -ForegroundColor Yellow "BuildUrl                        "; Write-Host $buildUrl
if ($enableAppSourceCop) {
    Write-Host -NoNewLine -ForegroundColor Yellow "Mandatory Affixes               "; Write-Host ($AppSourceCopMandatoryAffixes -join ',')
    Write-Host -NoNewLine -ForegroundColor Yellow "Supported Countries             "; Write-Host ($AppSourceCopSupportedCountries -join ',')
    Write-Host -NoNewLine -ForegroundColor Yellow "ObsoleteTagMinAllowedMajorMinor "; Write-Host $obsoleteTagMinAllowedMajorMinor
}
Write-Host -ForegroundColor Yellow "Install Apps"
if ($installApps) { $installApps | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Install Test Apps"
if ($installTestApps) { $installTestApps | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Previous Apps"
if ($previousApps) { $previousApps | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Application folders"
if ($appFolders) { $appFolders | ForEach-Object { Write-Host "- $_" } }  else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Test application folders"
if ($testFolders) { $testFolders | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "BCPT Test application folders"
if ($bcptTestFolders) { $bcptTestFolders | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "BCPT Test suites"
if ($bcptTestSuites) { $bcptTestSuites | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Page Scripting Tests"
if ($pageScriptingTests) { $pageScriptingTests | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Custom CodeCops"
if ($customCodeCops) { $customCodeCops | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }

$runTestApps = @($installTestApps)
if ($installOnlyReferencedApps) {
    # Some dependencies in installApps might be skipped due to missing references if InstallOnlyReferencedApps is specified
    $installTestApps += @($installApps)
}

$vsixFile = DetermineVsixFile -vsixFile $vsixFile
$compilerFolder = ''
$createContainer = $true

if ($useCompilerFolder) {
    # We are using CompilerFolder, no need for a filesOnly Container
    # If we are to create a container, it is for publishing and testing
    $filesOnly = $false
    $updateLaunchJson = ''
    $createContainer = !($doNotPublishApps -or ($bcAuthContext -and $environment))
    if (!$createContainer) { $containerName = ''}
}
elseif ($doNotPublishApps) {
    # We are not using CompilerFolder, but we are not publishing apps either
    # we can use FilesOnly container
    $filesOnly = $true
    $CopySymbolsFromContainer = $true
    $testToolkitInstalled = $true
}

if ($doNotPublishApps) {
    # If we are not going to publish apps, we also cannot run upgrade tests or tests
    $doNotRunTests = $true
    $doNotRunBcptTests = $true
    $doNotRunPageScriptingTests = $true
    $doNotPerformUpgrade = $true
}

if ($doNotBuildTests) {
    # If we are not going to build tests, set test folders to empty
    # and set doNotRunTests and doNotRunBcptTests to true
    $testFolders = @()
    $bcptTestFolders = @()
    $installTestRunner = $false
    $installTestFramework = $false
    $installTestLibraries = $false
    $installPerformanceToolkit = $false
    $doNotRunTests = $true
    $doNotRunBcptTests = $true
    $doNotRunPageScriptingTests = $true
}

if (!$createContainer -or $filesOnly) {
    # If we are not creating a full container, do not backup and restore databases
    if ($restoreDatabases) {
        Write-Host -ForegroundColor Yellow "WARNING: Ignoring restoreDatabases as we are not creating a full container"
        $restoreDatabases = @()
    }
    # And do not test additional countries
    $additionalCountries = @()
}

if ($DockerPull) {
    Write-Host -ForegroundColor Yellow "DockerPull override"; Write-Host $DockerPull.ToString()
}
else {
    $DockerPull = { Param($imageName) docker pull $imageName --quiet }
}
if ($NewBcContainer) {
    Write-Host -ForegroundColor Yellow "NewBccontainer override"; Write-Host $NewBcContainer.ToString()
}
else {
    $NewBcContainer = { Param([Hashtable]$parameters) New-BcContainer @parameters; Invoke-ScriptInBcContainer $parameters.ContainerName -scriptblock { $progressPreference = 'SilentlyContinue' } }
}
if ($SetBcContainerKeyVaultAadAppAndCertificate) {
    Write-Host -ForegroundColor Yellow "SetBcContainerKeyVaultAadAppAndCertificate override"; Write-Host $SetBcContainerKeyVaultAadAppAndCertificate.ToString()
}
else {
    $SetBcContainerKeyVaultAadAppAndCertificate = { Param([Hashtable]$parameters) Set-BcContainerKeyVaultAadAppAndCertificate @parameters }
}
if ($ImportTestToolkitToBcContainer) {
    Write-Host -ForegroundColor Yellow "ImportTestToolkitToBcContainer override"; Write-Host $ImportTestToolkitToBcContainer.ToString()
}
else {
    $ImportTestToolkitToBcContainer = { Param([Hashtable]$parameters) Import-TestToolkitToBcContainer @parameters }
}
if ($CompileAppInBcContainer) {
    Write-Host -ForegroundColor Yellow "CompileAppInBcContainer override"; Write-Host $CompileAppInBcContainer.ToString()
}
else {
    $CompileAppInBcContainer = { Param([Hashtable]$parameters) Compile-AppInBcContainer @parameters }
}
if ($CompileAppWithBcCompilerFolder) {
    Write-Host -ForegroundColor Yellow "CompileAppWithBcCompilerFolder override"; Write-Host $CompileAppWithBcCompilerFolder.ToString()
}
else {
    $CompileAppWithBcCompilerFolder = { Param([Hashtable]$parameters) Compile-AppWithBcCompilerFolder @parameters }
}

if ($PreCompileApp) {
    Write-Host -ForegroundColor Yellow "Custom pre-compilation script defined."; Write-Host $PreCompileApp.ToString()
}

if ($PostCompileApp) {
    Write-Host -ForegroundColor Yellow "Custom post-compilation script defined."; Write-Host $PostCompileApp.ToString()
}

if ($GetBcContainerAppInfo) {
    Write-Host -ForegroundColor Yellow "GetBcContainerAppInfo override"; Write-Host $GetBcContainerAppInfo.ToString()
}
else {
    $GetBcContainerAppInfo = { Param([Hashtable]$parameters) Get-BcContainerAppInfo @parameters }
}
if ($PublishBcContainerApp) {
    Write-Host -ForegroundColor Yellow "PublishBcContainerApp override"; Write-Host $PublishBcContainerApp.ToString()
}
else {
    $PublishBcContainerApp = { Param([Hashtable]$parameters) Publish-BcContainerApp @parameters }
}
if ($UnPublishBcContainerApp) {
    Write-Host -ForegroundColor Yellow "UnPublishBcContainerApp override"; Write-Host $UnPublishBcContainerApp.ToString()
}
else {
    $UnPublishBcContainerApp = { Param([Hashtable]$parameters) UnPublish-BcContainerApp @parameters }
}
if ($InstallBcAppFromAppSource) {
    Write-Host -ForegroundColor Yellow "InstallBcAppFromAppSource override"; Write-Host $InstallBcAppFromAppSource.ToString()
}
else {
    $InstallBcAppFromAppSource = { Param([Hashtable]$parameters) Install-BcAppFromAppSource @parameters }
}
if ($SignBcContainerApp) {
    Write-Host -ForegroundColor Yellow "SignBcContainerApp override"; Write-Host $SignBcContainerApp.ToString()
}
else {
    $SignBcContainerApp = { Param([Hashtable]$parameters) Sign-BcContainerApp @parameters }
}
if ($ImportTestDataInBcContainer) {
    Write-Host -ForegroundColor Yellow "ImportTestDataInBcContainer override"; Write-Host $ImportTestDataInBcContainer.ToString()
}
if ($BackupBcContainerDatabases) {
    Write-Host -ForegroundColor Yellow "BackupBcContainerDatabases override"; Write-Host $BackupBcContainerDatabases.ToString()
}
else {
    $BackupBcContainerDatabases = { Param([Hashtable]$parameters) Backup-BcContainerDatabases @parameters }
}
if ($RestoreDatabasesInBcContainer) {
    Write-Host -ForegroundColor Yellow "RestoreDatabasesInBcContainer override"; Write-Host $RestoreDatabasesInBcContainer.ToString()
}
else {
    $RestoreDatabasesInBcContainer = { Param([Hashtable]$parameters) Restore-DatabasesInBcContainer @parameters }
}
if ($RunTestsInBcContainer) {
    Write-Host -ForegroundColor Yellow "RunTestsInBcContainer override"; Write-Host $RunTestsInBcContainer.ToString()
}
else {
    $RunTestsInBcContainer = { Param([Hashtable]$parameters) Run-TestsInBcContainer @parameters }
}
if ($RunBCPTTestsInBcContainer ) {
    Write-Host -ForegroundColor Yellow "RunBCPTTestsInBcContainer override"; Write-Host $RunBCPTTestsInBcContainer.ToString()
}
else {
    $RunBCPTTestsInBcContainer = { Param([Hashtable]$parameters) Run-BCPTTestsInBcContainer @parameters }
}
if ($GetBcContainerAppRuntimePackage) {
    Write-Host -ForegroundColor Yellow "GetBcContainerAppRuntimePackage override"; Write-Host $GetBcContainerAppRuntimePackage.ToString()
}
else {
    $GetBcContainerAppRuntimePackage = { Param([Hashtable]$parameters) Get-BcContainerAppRuntimePackage @parameters }
}
if ($RemoveBcContainer) {
    Write-Host -ForegroundColor Yellow "RemoveBcContainer override"; Write-Host $RemoveBcContainer.ToString()
}
else {
    $RemoveBcContainer = { Param([Hashtable]$parameters) Remove-BcContainer @parameters }
}
if ($GetBestGenericImageName) {
    Write-Host -ForegroundColor Yellow "GetBestGenericImageName override"; Write-Host $GetBestGenericImageName.ToString()
}
else {
    $GetBestGenericImageName = { Param([Hashtable]$parameters) Get-BestGenericImageName @parameters }
}
if ($GetBcContainerEventLog) {
    Write-Host -ForegroundColor Yellow "GetBcContainerEventLog override"; Write-Host $GetBcContainerEventLog.ToString()
}
else {
    $GetBcContainerEventLog = { Param([Hashtable]$parameters) Get-BcContainerEventLog @parameters }
}
if ($InstallMissingDependencies) {
    Write-Host -ForegroundColor Yellow "InstallMissingDependencies override"; Write-Host $InstallMissingDependencies.ToString()
}
Write-GroupEnd

$signApps = ($codeSignCertPfxFile -ne "")

Measure-Command {


$appsBeforeApps = @()
$apps = @()
$appsBeforeTestApps = @()
$testApps = @()
$bcptTestApps = @()

$err = $null
$prevProgressPreference = $progressPreference
$progressPreference = 'SilentlyContinue'

try {

@("")+$additionalCountries | ForEach-Object {
$testCountry = $_.Trim()
$testToolkitInstalled = $false

RemoveCompilerFolder
RemoveBuildContainer

if ($testCountry) {
    $artifactSegments = $artifactUrl.Split('?')[0].Split('/')
    $artifactUrl = $artifactUrl.Replace("/$($artifactSegments[4])/$($artifactSegments[5])","/$($artifactSegments[4])/$testCountry")
    Write-Host -ForegroundColor Yellow "Creating container for additional country $testCountry"
    # When testing additional countries, we are done compiling - no need for compilerfolder
    $useCompilerFolder = $false
}

Write-GroupStart -Message "Resolving dependencies"
Write-Host -ForegroundColor Yellow @'

 _____                _       _                   _                           _                 _
|  __ \              | |     (_)                 | |                         | |               (_)
| |__) |___ ___  ___ | |_   ___ _ __   __ _    __| | ___ _ __   ___ _ __   __| | ___ _ __   ___ _  ___ ___
|  _  // _ \ __|/ _ \| \ \ / / | '_ \ / _` |  / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \ __|
| | \ \  __\__ \ (_) | |\ V /| | | | | (_| | | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __\__ \
|_|  \_\___|___/\___/|_| \_/ |_|_| |_|\__, |  \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___|___/
                                       __/ |            | |
                                      |___/             |_|

'@
$unknownAppDependencies = @()
$unknownTestAppDependencies = @()
$sortedAppFolders = @(Sort-AppFoldersByDependencies -appFolders ($appFolders) -WarningAction SilentlyContinue -unknownDependencies ([ref]$unknownAppDependencies))
$sortedTestAppFolders = @(Sort-AppFoldersByDependencies -appFolders ($appFolders+$testFolders+$bcptTestFolders) -WarningAction SilentlyContinue -unknownDependencies ([ref]$unknownTestAppDependencies) | Where-Object { $appFolders -notcontains $_ })
Write-Host "Sorted App folders"
$sortedAppFolders | ForEach-Object { Write-Host "- $_" }
Write-Host "External dependencies"
if ($unknownAppDependencies) {
    $unknownAppDependencies | ForEach-Object { Write-Host "- $_" }
    $missingAppDependencies = $unknownAppDependencies | ForEach-Object { $_.Split(':')[0] }
}
else {
    Write-Host "- None"
    $missingAppDependencies = @()
}
$missingTestAppDependencies = @()
Write-Host "Sorted TestApp folders"
if ($sortedTestAppFolders.count -eq 0) {
    Write-Host "- None"
}
else {
    $sortedTestAppFolders | ForEach-Object { Write-Host "- $_" }
    Write-Host "External TestApp dependencies"
    if ($unknownTestAppDependencies) {
        $unknownTestAppDependencies | ForEach-Object { Write-Host "- $_" }
        $missingTestAppDependencies = $unknownTestAppDependencies | ForEach-Object { $_.Split(':')[0] }
    }
    else {
        Write-Host "- None"
    }
}
# Include unknown app dependencies from previous apps (which doesn't already exist in unknown app dependencies)
if ($previousApps) {
    Write-Host "Copying previous apps to packages folder"
    $tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    try {
        $unknownPreviousAppDependencies = @()
        $appList = CopyAppFilesToFolder -appFiles $previousApps -folder $tempFolder
        $sortedPreviousApps = Sort-AppFilesByDependencies -appFiles $appList -WarningAction SilentlyContinue -unknownDependencies ([ref]$unknownPreviousAppDependencies)
        Write-Host "Previous apps"
        $sortedPreviousApps | ForEach-Object { Write-Host "- $([System.IO.Path]::GetFileName($_))" }
        Write-Host "External previous app dependencies"
        if ($unknownPreviousAppDependencies) {
            # Add unknown Previous App Dependencies to missingAppDependencies
            foreach($appDependency in $unknownPreviousAppDependencies) {
                $appId = $appDependency.Split(':')[0]
                if ($appId -ne ([guid]::Empty.ToString())) {
                    Write-Host "- $appDependency"
                    if ($missingAppDependencies -notcontains $appId) {
                        $missingAppDependencies += @($appId)
                        $unknownAppDependencies += @($appDependency)
                    }
                }
            }
        }
        else {
            Write-Host "- None"
        }
    }
    finally {
        Remove-Item -Path $tempFolder -recurse -force
    }
}

Write-GroupEnd

if ($installApps) {
Write-GroupStart -Message "Installing apps"
Write-Host -ForegroundColor Yellow @'

  _____           _        _ _ _
 |_   _|         | |      | | (_)
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _    __ _ _ __  _ __  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` |  / _` | '_ \| '_ \/ __|
  _| |_| | | \__ \ |_ (_| | | | | | | | (_| | | (_| | |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__,_| .__/| .__/|___/
                                        __/ |       | |   | |
                                       |___/        |_|   |_|

'@
Measure-Command {

    if ($testCountry) {
        Write-Host -ForegroundColor Yellow "Installing apps for additional country $testCountry"
    }

    $tmpAppFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    $tmpAppFiles = @()
    $installApps | ForEach-Object{
        $appId = [Guid]::Empty
        if ([Guid]::TryParse($_, [ref] $appId)) {
            if (-not $bcAuthContext) {
                throw "InstallApps can only specify AppIds for AppSource Apps when running against a cloud instance"
            }
            if ($generateDependencyArtifact) {
                Write-Host -ForegroundColor Red "Cannot add AppSource Apps to dependency artifacts"
            }
            if ((!$installOnlyReferencedApps) -or ($missingAppDependencies -contains $appId)) {
                $Parameters = @{
                    "bcAuthContext" = $bcAuthContext
                    "environment" = $environment
                    "appId" = "$appId"
                    "acceptIsvEula" = $true
                    "installOrUpdateNeededDependencies" = $true
                }
                Invoke-Command -ScriptBlock $InstallBcAppFromAppSource -ArgumentList $Parameters
            }
        }
        elseif (!$testCountry -and ($useCompilerFolder -or ($filesOnly -and (-not $bcAuthContext)))) {
            CopyAppFilesToFolder -appfiles $_ -folder $packagesFolder | ForEach-Object {
                $appsBeforeApps += @($_)
                Write-Host -NoNewline "Copying $($_.SubString($packagesFolder.Length+1)) to symbols folder"
                if ($generateDependencyArtifact) {
                    Write-Host -NoNewline " and dependencies folder"
                    Copy-Item -Path $_ -Destination $dependenciesFolder -Force
                }
                Write-Host
            }
        }
        else {
            $tmpAppFiles += @(CopyAppFilesToFolder -appfiles $_ -folder $tmpAppFolder)
        }
    }

    if ($tmpAppFiles) {
        $Parameters = @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $tmpAppFiles
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
            "upgrade" = $true
            "ignoreIfAppExists" = $true
        }
        if ($installOnlyReferencedApps) {
            $parameters += @{
                "includeOnlyAppIds" = $missingAppDependencies
            }
        }
        if ($generateDependencyArtifact -and !($testCountry)) {
            $parameters += @{
                "CopyInstalledAppsToFolder" = $dependenciesFolder
            }
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
                "checkAlreadyInstalled" = $true
            }
        }
        if (!$doNotPublishApps) {
            Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
        }
        if (!$testCountry -and $useCompilerFolder) {
            Copy-AppFilesToCompilerFolder -compilerFolder (GetCompilerFolder) -appFiles $Parameters.appFile
        }

        Remove-Item -Path $tmpAppFolder -Recurse -Force
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}

if ($InstallMissingDependencies) {
$installedApps = @(GetInstalledApps -bcAuthContext $bcAuthContext -environment $environment -useCompilerFolder $useCompilerFolder -filesOnly $filesOnly -packagesFolder $packagesFolder)
if ($installedApps) {
    $missingAppDependencies = @($missingAppDependencies | Where-Object { $installedApps.Id -notcontains $_ })
}
if ($missingAppDependencies) {
Write-GroupStart -Message "Installing app dependencies"
Write-Host -ForegroundColor Yellow @'
  _____           _        _ _ _                                       _                           _                 _
 |_   _|         | |      | | (_)                                     | |                         | |               (_)
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _    __ _ _ __  _ __     __| | ___ _ __   ___ _ __   __| | ___ _ __   ___ _  ___  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` |  / _` | '_ \| '_ \   / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \/ __|
  _| |_| | | \__ \ || (_| | | | | | | | (_| | | (_| | |_) | |_) | | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __/\__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__,_| .__/| .__/   \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___||___/
                                        __/ |       | |   | |                | |
                                       |___/        |_|   |_|                |_|
'@
Measure-Command {
    Write-Host "Missing App dependencies"
    $missingAppDependencies | ForEach-Object { Write-Host "- $_" }
    if ($useCompilerFolder) {
        $appSymbolsFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -Path $appSymbolsFolder -ItemType Directory -Force | Out-Null
    }
    else {
        $appSymbolsFolder = $packagesFolder
    }
    $Parameters = @{
        "missingDependencies" = @($unknownAppDependencies | Where-Object { $missingAppDependencies -contains "$_".Split(':')[0] })
        "appSymbolsFolder" = $appSymbolsFolder
        "installedApps" = $installedApps
        "installedCountry" = $artifactUrl.Substring($artifactUrl.LastIndexOf('/')+1)
    }
    if (!($useCompilerFolder -or $filesOnly)) {
        $Parameters += @{
            "containerName" = (GetBuildcontainer)
            "tenant" = $tenant
        }
    }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
        }
    }
    if ($generateDependencyArtifact -and !($testCountry)) {
        $parameters += @{
            "CopyInstalledAppsToFolder" = $dependenciesFolder
        }
    }
    Invoke-Command -ScriptBlock $InstallMissingDependencies -ArgumentList $Parameters
    if ($useCompilerFolder) {
        Write-Host "check $appSymbolsFolder"
        Get-ChildItem -Path $appSymbolsFolder | ForEach-Object {
            Write-Host "Move $($_.Name) to $packagesFolder"
            Move-Item -Path $_.FullName -Destination $packagesFolder -Force
            $appsBeforeApps += @(Join-Path $packagesFolder $_.Name)
        }
        Remove-Item -Path $appSymbolsFolder -Recurse -Force
    }
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling app dependencies took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
}

if ((($testCountry) -or !($appFolders -or $testFolders -or $bcptTestFolders)) -and !$doNotPublishApps -and ($installTestRunner -or $installTestFramework -or $installTestLibraries -or $installPerformanceToolkit)) {
Write-GroupStart -Message "Importing test toolkit"
Write-Host -ForegroundColor Yellow @'
  _____                            _   _               _            _     _              _ _    _ _
 |_   _|                          | | (_)             | |          | |   | |            | | |  (_) |
   | |  _ __ ___  _ __   ___  _ __| |_ _ _ __   __ _  | |_ ___  ___| |_  | |_ ___   ___ | | | ___| |_
   | | | '_ ` _ \| '_ \ / _ \| '__| __| | '_ \ / _` | | __/ _ \/ __| __| | __/ _ \ / _ \| | |/ / | __|
  _| |_| | | | | | |_) | (_) | |  | |_| | | | | (_| | | ||  __/\__ \ |_  | || (_) | (_) | |   <| | |_
 |_____|_| |_| |_| .__/ \___/|_|   \__|_|_| |_|\__, |  \__\___||___/\__|  \__\___/ \___/|_|_|\_\_|\__|
                 | |                            __/ |
                 |_|                           |___/
'@
Measure-Command {
    Write-Host -ForegroundColor Yellow "Importing Test Toolkit for additional country $testCountry"
    $Parameters = @{
        "includeTestLibrariesOnly" = $installTestLibraries
        "includeTestFrameworkOnly" = !$installTestLibraries -and ($installTestFramework -or $installPerformanceToolkit)
        "includeTestRunnerOnly" = !$installTestLibraries -and !$installTestFramework -and ($installTestRunner -or $installPerformanceToolkit)
        "includePerformanceToolkit" = $installPerformanceToolkit
        "doNotUseRuntimePackages" = $true
        "useDevEndpoint" = $useDevEndpoint
    }
    if ($useCompilerFolder) {
        $Parameters += @{ "compilerFolder" = (GetCompilerFolder) }
    }
    if ($createContainer) {
        $Parameters += @{ "containerName" = (GetBuildContainer) }
    }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
        }
    }
    elseif ($useDevEndpoint) {
        $Parameters += @{
            "credential" = $credential
        }
    }
    Invoke-Command -ScriptBlock $ImportTestToolkitToBcContainer -ArgumentList $Parameters
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nImporting Test Toolkit took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd

if ($installTestApps) {
Write-GroupStart -Message "Installing test apps"
Write-Host -ForegroundColor Yellow @'
  _____           _        _ _ _               _            _
 |_   _|         | |      | | (_)             | |          | |
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _  | |_ ___  ___| |_    __ _ _ __  _ __  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | | __/ _ \/ __| __|  / _` | '_ \| '_ \/ __|
  _| |_| | | \__ \ || (_| | | | | | | | (_| | | ||  __/\__ \ |_  | (_| | |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__\___||___/\__|  \__,_| .__/| .__/|___/
                                        __/ |                          | |   | |
                                       |___/                           |_|   |_|
'@
Measure-Command {

    Write-Host -ForegroundColor Yellow "Installing test apps for additional country $testCountry"
    $tmpAppFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    $tmpAppFiles = @()
    $installTestApps | ForEach-Object{
        $appId = [Guid]::Empty
        if ([Guid]::TryParse($_, [ref] $appId)) {
            if (-not $bcAuthContext) {
                throw "InstallApps can only specify AppIds for AppSource Apps when running against a cloud instance"
            }
            if ((!$installOnlyReferencedApps) -or ($missingTestAppDependencies -contains $appId)) {
                $Parameters = @{
                    "bcAuthContext" = $bcAuthContext
                    "environment" = $environment
                    "appId" = "$appId"
                    "acceptIsvEula" = $true
                    "installOrUpdateNeededDependencies" = $true
                }
                Invoke-Command -ScriptBlock $InstallBcAppFromAppSource -ArgumentList $Parameters
            }
        }
        elseif (!$testCountry -and ($useCompilerFolder -or ($filesOnly -and (-not $bcAuthContext)))) {
            CopyAppFilesToFolder -appfiles "$_".Trim('()') -folder $packagesFolder | ForEach-Object {
                $appsBeforeTestApps += @($_)
            }
        }
        else {
            $tmpAppFiles += @(CopyAppFilesToFolder -appfiles "$_".Trim('()') -folder $tmpAppFolder)
        }
    }

    if ($tmpAppFiles) {
        $Parameters = @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $tmpAppFiles
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
            "upgrade" = $true
            "ignoreIfAppExists" = $true
        }
        if ($installOnlyReferencedApps) {
            $parameters += @{
                "includeOnlyAppIds" = $missingTestAppDependencies
            }
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
                "checkAlreadyInstalled" = $true
            }
        }
        if (!$doNotPublishApps) {
            Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
        }
    }
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling test apps took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
}

if ((($testCountry) -or !($appFolders -or $testFolders -or $bcptTestFolders)) -and ($InstallMissingDependencies)) {
$installedApps = @(GetInstalledApps -bcAuthContext $bcAuthContext -environment $environment -useCompilerFolder $useCompilerFolder -filesOnly $filesOnly -compilerFolder (GetCompilerFolder) -packagesFolder $packagesFolder)
if ($installedApps) {
    $missingTestAppDependencies = @($missingTestAppDependencies | Where-Object { $installedApps.Id -notcontains $_ })
}
if ($missingTestAppDependencies) {
Write-GroupStart -Message "Installing test app dependencies"
Write-Host -ForegroundColor Yellow @'
  _____           _        _ _ _               _            _                             _                           _                 _
 |_   _|         | |      | | (_)             | |          | |                           | |                         | |               (_)
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _  | |_ ___  ___| |_    __ _ _ __  _ __     __| | ___ _ __   ___ _ __   __| | ___ _ __   ___ _  ___  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | | __/ _ \/ __| __|  / _` | '_ \| '_ \   / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \/ __|
  _| |_| | | \__ \ || (_| | | | | | | | (_| | | ||  __/\__ \ |_  | (_| | |_) | |_) | | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __/\__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__\___||___/\__|  \__,_| .__/| .__/   \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___||___/
                                        __/ |                          | |   | |                | |
                                       |___/                           |_|   |_|                |_|
'@
Measure-Command {
    Write-Host "Missing TestApp dependencies"
    $missingTestAppDependencies | ForEach-Object { Write-Host "- $_" }
    if ($useCompilerFolder) {
        $appSymbolsFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -Path $appSymbolsFolder -ItemType Directory -Force | Out-Null
    }
    else {
        $appSymbolsFolder = $packagesFolder
    }
    $Parameters = @{
        "missingDependencies" = @($unknownTestAppDependencies | Where-Object { $missingTestAppDependencies -contains "$_".Split(':')[0] })
        "appSymbolsFolder" = $appSymbolsFolder
        "installedApps" = $installedApps
        "installedCountry" = $artifactUrl.Substring($artifactUrl.LastIndexOf('/')+1)
    }
    if (!($useCompilerFolder -or $filesOnly)) {
        $Parameters += @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
        }
    }
    Invoke-Command -ScriptBlock $InstallMissingDependencies -ArgumentList $Parameters
    if ($useCompilerFolder) {
        Copy-Item -Path (Join-Path $appSymbolsFolder '*') -Destination $packagesFolder -Force
        Remove-Item -Path $appSymbolsFolder -Recurse -Force
        $appsBeforeTestApps += @(Join-Path $packagesFolder $_.Name)
    }
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling testapp dependencies took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
}

if (-not $testCountry) {
if ($appFolders -or $testFolders -or $bcptTestFolders) {
Write-GroupStart -Message "Compiling apps"
Write-Host -ForegroundColor Yellow @'

   _____                      _ _ _
  / ____|                    (_) (_)
 | |     ___  _ __ ___  _ __  _| |_ _ __   __ _    __ _ _ __  _ __  ___
 | |    / _ \| '_ ` _ \| '_ \| | | | '_ \ / _` |  / _` | '_ \| '_ \/ __|
 | |____ (_) | | | | | | |_) | | | | | | | (_| | | (_| | |_) | |_) \__ \
  \_____\___/|_| |_| |_| .__/|_|_|_|_| |_|\__, |  \__,_| .__/| .__/|___/
                       | |                 __/ |       | |   | |
                       |_|                |___/        |_|   |_|

'@
}
$measureText = ""
Measure-Command {
$previousAppsCopied = $false
$previousAppInfos = @()
$appsFolder = @{}
$prebuiltApps = @()
$sortedAppFolders+$sortedTestAppFolders | Select-Object -Unique | ForEach-Object {
    $folder = $_

    $bcptTestApp = $bcptTestFolders.Contains($folder)
    $testApp = $testFolders.Contains($folder)
    $app = $appFolders.Contains($folder)
    if (($testApp -or $bcptTestApp) -and !$testToolkitInstalled -and ($installTestRunner -or $installTestFramework -or $installTestLibraries -or $installPerformanceToolkit)) {

Write-GroupEnd
if (!$doNotPublishApps) {
Write-GroupStart -Message "Importing test toolkit"
Write-Host -ForegroundColor Yellow @'
  _____                            _   _               _            _     _              _ _    _ _
 |_   _|                          | | (_)             | |          | |   | |            | | |  (_) |
   | |  _ __ ___  _ __   ___  _ __| |_ _ _ __   __ _  | |_ ___  ___| |_  | |_ ___   ___ | | | ___| |_
   | | | '_ ` _ \| '_ \ / _ \| '__| __| | '_ \ / _` | | __/ _ \/ __| __| | __/ _ \ / _ \| | |/ / | __|
  _| |_| | | | | | |_) | (_) | |  | |_| | | | | (_| | | ||  __/\__ \ |_  | || (_) | (_) | |   <| | |_
 |_____|_| |_| |_| .__/ \___/|_|   \__|_|_| |_|\__, |  \__\___||___/\__|  \__\___/ \___/|_|_|\_\_|\__|
                 | |                            __/ |
                 |_|                           |___/
'@
Measure-Command {
    $measureText = ", test apps and importing test toolkit"
    $Parameters = @{
        "includeTestLibrariesOnly" = $installTestLibraries
        "includeTestFrameworkOnly" = !$installTestLibraries -and ($installTestFramework -or $installPerformanceToolkit)
        "includeTestRunnerOnly" = !$installTestLibraries -and !$installTestFramework -and ($installTestRunner -or $installPerformanceToolkit)
        "includePerformanceToolkit" = $installPerformanceToolkit
    }
    if ($useCompilerFolder) {
        $Parameters += @{ "compilerFolder" = (GetCompilerFolder) }
    }
    if ($useCompilerFolder -and !$bcAuthContext) {
        Write-Host "Get TestToolkit Apps"
        $appsBeforeTestApps += GetTestToolkitApps @Parameters
    }
    else {
        if ($createContainer) {
            $Parameters += @{
                "containerName" = (GetBuildContainer)
                "doNotUseRuntimePackages" = $true
                "useDevEndpoint" = $useDevEndpoint
            }
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
            }
        } elseif ($useDevEndpoint) {
            $Parameters += @{
                "credential" = $credential
            }
        }
        Invoke-Command -ScriptBlock $ImportTestToolkitToBcContainer -ArgumentList $Parameters
    }
    $testToolkitInstalled = $true
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nImporting Test Toolkit took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
if ($installTestApps) {
Write-GroupStart -Message "Installing test apps"
Write-Host -ForegroundColor Yellow @'
  _____           _        _ _ _               _            _
 |_   _|         | |      | | (_)             | |          | |
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _  | |_ ___  ___| |_    __ _ _ __  _ __  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | | __/ _ \/ __| __|  / _` | '_ \| '_ \/ __|
  _| |_| | | \__ \ || (_| | | | | | | | (_| | | ||  __/\__ \ |_  | (_| | |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__\___||___/\__|  \__,_| .__/| .__/|___/
                                        __/ |                          | |   | |
                                       |___/                           |_|   |_|
'@
Measure-Command {

    Write-Host -ForegroundColor Yellow "Installing test apps"
    $tmpAppFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    $tmpAppFiles = @()
    $installTestApps | ForEach-Object{
        $appId = [Guid]::Empty
        if ([Guid]::TryParse($_, [ref] $appId)) {
            if (-not $bcAuthContext) {
                throw "InstallApps can only specify AppIds for AppSource Apps when running against a cloud instance"
            }
            if ((!$installOnlyReferencedApps) -or ($missingTestAppDependencies -contains $appId)) {
                $Parameters = @{
                    "bcAuthContext" = $bcAuthContext
                    "environment" = $environment
                    "appId" = "$appId"
                    "acceptIsvEula" = $true
                    "installOrUpdateNeededDependencies" = $true
                }
                Invoke-Command -ScriptBlock $InstallBcAppFromAppSource -ArgumentList $Parameters
            }
        }
        elseif (!$testCountry -and ($useCompilerFolder -or ($filesOnly -and (-not $bcAuthContext)))) {
            CopyAppFilesToFolder -appfiles "$_".Trim('()') -folder $packagesFolder | ForEach-Object {
                $appsBeforeTestApps += @($_)
            }
        }
        else {
            $tmpAppFiles += @(CopyAppFilesToFolder -appfiles "$_".Trim('()') -folder $tmpAppFolder)
        }
    }

    if ($tmpAppFiles) {
        $Parameters = @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $tmpAppFiles
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
            "upgrade" = $true
            "ignoreIfAppExists" = $true
        }
        if ($installOnlyReferencedApps) {
            $parameters += @{
                "includeOnlyAppIds" = $missingTestAppDependencies
            }
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
                "checkAlreadyInstalled" = $true
            }
        }
        if (!$doNotPublishApps) {
            Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
        }
        if ($useCompilerFolder) {
            Copy-AppFilesToCompilerFolder -compilerFolder (GetCompilerFolder) -appFiles $tmpAppFiles
        }
        Remove-Item -Path $tmpAppFolder -Recurse -Force
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling test apps took $([int]$_.TotalSeconds) seconds" }
}
Write-GroupEnd

if ($InstallMissingDependencies) {
$installedApps = @(GetInstalledApps -bcAuthContext $bcAuthContext -environment $environment -useCompilerFolder $useCompilerFolder -filesOnly $filesOnly -packagesFolder $packagesFolder)
if ($installedApps) {
    $missingTestAppDependencies = @($missingTestAppDependencies | Where-Object { $installedApps.Id -notcontains $_ })
}
if ($missingTestAppDependencies) {
Write-GroupStart -Message "Installing test app dependencies"
Write-Host -ForegroundColor Yellow @'
  _____           _        _ _ _               _            _                             _                           _                 _
 |_   _|         | |      | | (_)             | |          | |                           | |                         | |               (_)
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _  | |_ ___  ___| |_    __ _ _ __  _ __     __| | ___ _ __   ___ _ __   __| | ___ _ __   ___ _  ___  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | | __/ _ \/ __| __|  / _` | '_ \| '_ \   / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \/ __|
  _| |_| | | \__ \ || (_| | | | | | | | (_| | | ||  __/\__ \ |_  | (_| | |_) | |_) | | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __/\__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__\___||___/\__|  \__,_| .__/| .__/   \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___||___/
                                        __/ |                          | |   | |                | |
                                       |___/                           |_|   |_|                |_|
'@
Measure-Command {
    Write-Host "Missing TestApp dependencies"
    $missingTestAppDependencies | ForEach-Object { Write-Host "- $_" }
    $Parameters = @{
        "missingDependencies" = @($unknownTestAppDependencies | Where-Object { $missingTestAppDependencies -contains "$_".Split(':')[0] })
        "appSymbolsFolder" = $packagesFolder
    }
    if (!($useCompilerFolder -or $filesOnly)) {
        $Parameters += @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
        }
    }
    Invoke-Command -ScriptBlock $InstallMissingDependencies -ArgumentList $Parameters
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling testapp dependencies took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
}

Write-GroupStart -Message "Compiling test apps"
Write-Host -ForegroundColor Yellow @'
   _____                      _ _ _               _           _
  / ____|                    (_) (_)             | |         | |
 | |     ___  _ __ ___  _ __  _| |_ _ __   __ _  | |_ ___ ___| |_    __ _ _ __  _ __  ___
 | |    / _ \| '_ ` _ \| '_ \| | | | '_ \ / _` | | __/ _ \ __| __|  / _` | '_ \| '_ \/ __|
 | |____ (_) | | | | | | |_) | | | | | | | (_| | | |_  __\__ \ |_  | (_| | |_) | |_) \__ \
  \_____\___/|_| |_| |_| .__/|_|_|_|_| |_|\__, |  \__\___|___/\__|  \__,_| .__/| .__/|___/
                       | |                 __/ |                         | |   | |
                       |_|                |___/                          |_|   |_|
'@
    }

    $appJsonFile = Join-Path $folder "app.json"
    $appJsonChanges = $false
    $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json

    $prebuiltAppFileName = ''
    $prebuiltAppName = "$($appJson.Publisher)_$($appJson.Name)".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
    if ($buildArtifactFolder) {
        $prebuiltFolderName = Join-Path $buildArtifactFolder "$(if($app){"Apps"}else{"TestApps"})"
        $prebuiltAppFileName = Join-Path $prebuiltFolderName "$($prebuiltAppName)_*.*.*.*.app"
        if (Test-Path $prebuiltAppFileName) {
            $prebuiltAppFileName = (Get-Item $prebuiltAppFileName).FullName
            if ($prebuiltAppFileName -is [Array]) {
                Write-Host "Multiple apps found for prebuilt app - rebuilding app!"
                $prebuiltAppFileName = ''
            }
        }
        else {
            $prebuiltAppFileName = ''
        }
    }
    if ($useDevEndpoint) {
        $appPackagesFolder = Join-Path $folder ".alPackages"
        $appOutputFolder = $folder
    }
    else {
        $appPackagesFolder = $packagesFolder
        $appOutputFolder = $outputFolder
    }
    if ($prebuiltAppFileName) {
        Write-Host "Using prebuilt app $prebuiltAppFileName"
        $prebuiltApps += @($prebuiltAppFileName)
        $appFile = $prebuiltAppFileName
        Copy-Item -Path $appFile -Destination $appPackagesFolder -Force
    }
    else {
    $Parameters = @{ }
    $CopParameters = @{ }

    if ($bcAuthContext -and !$useCompilerFolder) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
        }
    }

    if ($app -or $enableCodeAnalyzersOnTestApps) {
        $CopParameters += @{
            "EnableCodeCop" = $enableCodeCop
            "EnableAppSourceCop" = $enableAppSourceCop
            "EnableUICop" = $enableUICop
            "EnablePerTenantExtensionCop" = $enablePerTenantExtensionCop
            "failOn" = $failOn
        }

        if ($customCodeCops.Count -gt 0) {
            $CopParameters += @{
                "CustomCodeCops" = $customCodeCops
            }
        }

        if ($enableExternalRulesets) {
            $CopParameters += @{
                "EnableExternalRulesets" = $true
            }
        }
        if ("$rulesetFile" -ne "" -or $useDefaultAppSourceRuleSet) {
            if ($useDefaultAppSourceRuleSet) {
                Write-Host "Creating ruleset for pipeline"
                $ruleset = [ordered]@{
                    "name" = "Run-AlPipeline RuleSet"
                    "description" = "Generated by Run-AlPipeline"
                    "includedRuleSets" = @()
                }
                if ($rulesetFile) {
                    Write-Host "Including custom ruleset"
                    $ruleset.includedRuleSets += @(@{
                        "action" = "Default"
                        "path" = Get-BcContainerPath -containerName (GetBuildContainer) -path $ruleSetFile
                    })
                }
                $appSourceRuleSetName = 'appsource.default.ruleset.json'
                $appSourceRulesetFile = Join-Path $folder $appSourceRuleSetName
                Copy-Item -Path (Join-Path $PSScriptRoot $appSourceRuleSetName) -Destination $appSourceRulesetFile -Force
                $ruleset.includedRuleSets += @(@{
                    "action" = "Default"
                    "path" = Get-BcContainerPath -containerName (GetBuildContainer) -path $appSourceRulesetFile
                })
                $RuleSetFile = Join-Path $folder "run-alpipeline.ruleset.json"
                $ruleset | ConvertTo-Json -Depth 99 | Set-Content $rulesetFile
            }
            else {
                Write-Host "Using custom ruleset"
            }
            $CopParameters += @{
                "ruleset" = $rulesetFile
            }
        }
    }
    if (($bcAuthContext) -and $testApp -and ($enablePerTenantExtensionCop -or $enableAppSourceCop)) {
        Write-Host -ForegroundColor Yellow "WARNING: A Test App cannot be published to production tenants online"
    }

    if ($appVersion -or $appBuild -or $appRevision) {
        if ($appVersion) {
            $version = [System.Version]"$($appVersion).$($appBuild).$($appRevision)"
        }
        else {
            $appJsonVersion = [System.Version]$appJson.Version
            if ($appBuild -eq -1) {
       	        $version = [System.Version]::new($appJsonVersion.Major, $appJsonVersion.Minor, $appJsonVersion.Build, $appRevision)
            }
            else {
                $version = [System.Version]::new($appJsonVersion.Major, $appJsonVersion.Minor, $appBuild, $appRevision)
            }
        }
        Write-Host "Using Version $version"
        $appJson.version = "$version"
        $appJsonChanges = $true
    }

    try {
        if ($app -and $appJson.ShowMyCode) {
            $warningsToShow += "NOTE: The app in $folder has ShowMyCode set to true. This means that people will be able to debug and see the source code of your app. (see https://aka.ms/showMyCode)"
        }
    }
    catch {}

    $bcVersion = [System.Version]$artifactUrl.Split('/')[4]
    if($app) {
        $runtime = -1
        if ($appJson.psobject.Properties.name -eq "runtime") { $runtime = [double]$appJson.runtime }
        if(($applicationInsightsConnectionString) -and (($runtime -ge 7.2) -or (($runtime -eq -1) -and ($bcVersion -ge [System.Version]"18.2")))) {
            if ($appJson.psobject.Properties.name -eq "applicationInsightsConnectionString") {
                $appJson.applicationInsightsConnectionString = $applicationInsightsConnectionString
            }
            else {
                Add-Member -InputObject $appJson -MemberType NoteProperty -Name "applicationInsightsConnectionString" -Value $applicationInsightsConnectionString
            }
            $appJsonChanges = $true
        }
        elseif($applicationInsightsKey) {
            if ($appJson.psobject.Properties.name -eq "applicationInsightskey") {
                $appJson.applicationInsightsKey = $applicationInsightsKey
            }
            else {
                Add-Member -InputObject $appJson -MemberType NoteProperty -Name "applicationInsightsKey" -Value $applicationInsightsKey
            }
            $appJsonChanges = $true
        }
    }

    if ($appJsonChanges) {
        $appJsonContent = $appJson | ConvertTo-Json -Depth 99
        [System.IO.File]::WriteAllLines($appJsonFile, $appJsonContent)
    }

    if (!$useDevEndpoint) {
        $Parameters += @{ "CopyAppToSymbolsFolder" = $true }
    }

    if ($useCompilerFolder) {
        $Parameters += @{
            "compilerFolder" = (GetCompilerFolder)
        }
    }
    else {
        $Parameters += @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "credential" = $credential
            "CopySymbolsFromContainer" = $CopySymbolsFromContainer
        }
    }

    if ($generateDependencyArtifact -and !$filesOnly -and !$useCompilerFolder) {
        Write-Host "Copying dependencies from $dependenciesFolder to $appPackagesFolder"
        Get-ChildItem -Path $dependenciesFolder -Recurse -file -Filter '*.app' | ForEach-Object {
            $destName = Join-Path $appPackagesFolder $_.Name
            if (Test-Path $destName) {
                 Write-Host "- $destName already exists"
            }
            else {
                Write-Host "+ Copying $($_.FullName) to $destName"
                Copy-Item -Path $_.FullName -Destination $destName -Force
            }
        }
    }

    $Parameters += @{
        "appProjectFolder" = $folder
        "appOutputFolder" = $appOutputFolder
        "appSymbolsFolder" = $appPackagesFolder
        "AzureDevOps" = $azureDevOps
        "GitHubActions" = $gitHubActions
        "preProcessorSymbols" = $preProcessorSymbols
        "generatecrossreferences" = $generatecrossreferences
        "updateDependencies" = $UpdateDependencies
        "features" = $features
        "generateErrorLog" = $generateErrorLog
    }

    if ($buildOutputFile) {
        $parameters.OutputTo = { Param($line)
            Write-Host $line
            if ($line -like "$($folder)*") {
                Add-Content -Path $buildOutputFile -Value $line.SubString($folder.Length+1) -Encoding UTF8
            }
            else {
                Add-Content -Path $buildOutputFile -Value $line -Encoding UTF8
            }
        }
    }

    if ($app) {
        if (!$previousAppsCopied) {
            $previousAppsCopied = $true
            $AppList = @()
            $previousAppVersions = @{}
            if ($previousApps) {
                Write-Host "Copying previous apps to packages folder"
                $appList = CopyAppFilesToFolder -appFiles $previousApps -folder $appPackagesFolder
                $previousApps = Sort-AppFilesByDependencies -appFiles $appList
                $previousApps | ForEach-Object {
                    $appFile = $_
                    $appInfo = RunAlTool -arguments @('GetPackageManifest', """$appFile""") | ConvertFrom-Json
                    $appId = $appInfo.Id
                    Write-Host "$($appInfo.Publisher)_$($appInfo.Name) = $($appInfo.Version.ToString())"
                    $previousAppVersions += @{ "$($appInfo.Publisher)_$($appInfo.Name)" = $appInfo.Version.ToString() }
                    $previousAppInfos += @(@{
                        "AppId" = $appId.ToLowerInvariant()
                        "Publisher" = $appInfo.Publisher
                        "Name" = $appInfo.Name
                        "Version" = $appInfo.Version
                    } )
                }
            }
        }
    }

    if ($enableAppSourceCop -and $app) {
        $appSourceCopJson = @{}
        $saveit = $false

        if ($AppSourceCopMandatoryAffixes) {
            $appSourceCopJson += @{ "mandatoryAffixes" = @()+$AppSourceCopMandatoryAffixes }
            $saveit = $true
        }
        if ($AppSourceCopSupportedCountries) {
            $appSourceCopJson += @{ "supportedCountries" = @()+$AppSourceCopSupportedCountries }
            $saveit = $true
        }
        if ($ObsoleteTagMinAllowedMajorMinor) {
            $appSourceCopJson += @{ "obsoleteTagMinAllowedMajorMinor" = $ObsoleteTagMinAllowedMajorMinor }
            $saveit = $true
        }

        if ($previousAppVersions.ContainsKey("$($appJson.Publisher)_$($appJson.Name)")) {
            $appSourceCopJson += @{
                "Publisher" = $appJson.Publisher
                "Name" = $appJson.Name
                "Version" = $previousAppVersions."$($appJson.Publisher)_$($appJson.Name)"
            }
            $saveit = $true
        }
        $appSourceCopJsonFile = Join-Path $folder "AppSourceCop.json"
        if ($saveit) {
            Write-Host "Creating AppSourceCop.json for validation"
            $appSourceCopJson | ConvertTo-Json -Depth 99 | Set-Content $appSourceCopJsonFile
            Write-Host "AppSourceCop.json content:"
            $appSourceCopJson | ConvertTo-Json -Depth 99 | Out-Host
        }
        else {
            if (Test-Path $appSourceCopJsonFile) {
                Remove-Item $appSourceCopJsonFile -force
            }
        }
    }

    $appType = switch ($true) {
        $app { "app" }
        $testApp { "testApp" }
        $bcptTestApp { "bcptApp" }
        Default { "app" }
    }

    $Parameters += @{
        "sourceRepositoryUrl" = $sourceRepositoryUrl
        "sourceCommit" = $sourceCommit
        "buildBy" = $buildBy
        "buildUrl" = $buildUrl
    }

    $compilationParams = $Parameters + $CopParameters

    # Run pre-compile script if specified
    if($PreCompileApp) {
        Write-Host "Running custom pre-compilation script..."

        Invoke-Command -ScriptBlock $PreCompileApp -ArgumentList $appType, ([ref] $compilationParams)
    }

    try {
        Write-Host "`nCompiling $($compilationParams.appProjectFolder)"
        if ($useCompilerFolder) {
            $appFile = Invoke-Command -ScriptBlock $CompileAppWithBcCompilerFolder -ArgumentList $compilationParams
        }
        else {
            $appFile = Invoke-Command -ScriptBlock $CompileAppInBcContainer -ArgumentList $compilationParams
        }
    }
    catch {
        if ($escapeFromCops) {
            Write-Host "Retrying without Cops"

            # Remove Cops parameters
            $compilationParamsCopy = $compilationParams.Clone()
            $compilationParamsCopy.Keys | Where-Object {$_ -in $CopParameters.Keys} | ForEach-Object { $compilationParams.Remove($_) }

            if ($useCompilerFolder) {
                $appFile = Invoke-Command -ScriptBlock $CompileAppWithBcCompilerFolder -ArgumentList $compilationParams
            }
            else {
                $appFile = Invoke-Command -ScriptBlock $CompileAppInBcContainer -ArgumentList $compilationParams
            }
        }
        else {
            throw $_
        }
    }
    finally {
        # Copy error logs to build artifact folder
        if($generateErrorLog -and $buildArtifactFolder) {
            # Define destination folder for error logs
            $destFolder = Join-Path $buildArtifactFolder "ErrorLogs"
            if (!(Test-Path $destFolder -PathType Container)) {
                New-Item $destFolder -ItemType Directory | Out-Null
            }

            $errorLogFile = Join-Path $appOutputFolder '*.errorLog.json' -Resolve -ErrorAction Ignore
            if($errorLogFile) {
                Write-Host "Copying error logs to $destFolder"
                Copy-Item $errorLogFile $destFolder -Force
            }
        }
    }

    # Run post-compile script if specified
    if($PostCompileApp) {
        Write-Host "Running custom post-compilation script..."

        Invoke-Command -ScriptBlock $PostCompileApp -ArgumentList $appFile, $appType, $compilationParams
    }
    }

    if ($useDevEndpoint) {

        $Parameters = @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $appFile
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
            "useDevEndpoint" = $useDevEndpoint
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
                "checkAlreadyInstalled" = $true
            }
        }

        if (!$doNotPublishApps) {
            Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
        }
        if ($useCompilerFolder) {
            Copy-AppFilesToCompilerFolder -compilerFolder (GetCompilerFolder) -appFiles $Parameters.appFile
        }

        if ($updateLaunchJson) {
            $launchJsonFile = Join-Path $folder ".vscode\launch.json"
            if ($bcAuthContext) {
                $launchSettings = [ordered]@{
                    "type" = 'al'
                    "request" = 'launch'
                    "name" = $updateLaunchJson
                    "environmentType" = "Sandbox"
                    "environmentName" = $environment
                }
            }
            else {
                $containerName = GetBuildContainer
                $config = Get-BcContainerServerConfiguration $containerName
                $webUri = [Uri]::new($config.PublicWebBaseUrl)
                try {
                    $inspect = docker inspect $containerName | ConvertFrom-Json
                    if ($inspect.config.Labels.'traefik.enable' -eq 'true') {
                        $server = "$($inspect.config.Labels.'traefik.protocol')://$($webUri.Authority)"
                        if ($inspect.config.Labels.'traefik.protocol' -eq 'http') {
                            $port = 80
                        }
                        else {
                            $port = 443
                        }
                        $serverInstance = "$($containerName)dev"
                    }
                    else {
                        $server = "$($webUri.Scheme)://$($webUri.Authority)"
                        $port = $config.DeveloperServicesPort
                        $serverInstance = $webUri.AbsolutePath.Trim('/')
                    }
                }
                catch {
                    $server = "$($webUri.Scheme)://$($webUri.Authority)"
                    $port = $config.DeveloperServicesPort
                    $serverInstance = $webUri.AbsolutePath.Trim('/')
                }

                $launchSettings = [ordered]@{
                    "type" = 'al'
                    "request" = 'launch'
                    "name" = $updateLaunchJson
                    "server" = $Server
                    "serverInstance" = $serverInstance
                    "port" = [int]$Port
                    "tenant" = $tenant
                    "authentication" =  $auth
                }
            }
            UpdateLaunchJson -launchJsonFile $launchJsonFile -launchSettings $launchSettings
        }
    }

    if ($bcptTestApp) {
        $bcptTestApps += $appFile
    }
    if ($testApp) {
        $testApps += $appFile
    }
    if ($app) {
        $apps += $appFile
        $appsFolder += @{ "$appFile" = $folder }
    }
}
} | ForEach-Object { if ($appFolders -or $testFolders -or $bcptTestFolders) { Write-Host -ForegroundColor Yellow "`nCompiling apps$measureText took $([int]$_.TotalSeconds) seconds" } }
Write-GroupEnd

if ($signApps -and !$useDevEndpoint -and !$useCompilerFolder) {
Write-GroupStart -Message "Signing apps"
Write-Host -ForegroundColor Yellow @'
  _____ _             _
 / ____(_)           (_)
 | (__  _  __ _ _ __  _ _ __   __ _    __ _ _ __  _ __  ___
 \___ \| |/ _` | '_ \| | '_ \ / _` |  / _` | '_ \| '_ \/ __|
 ____) | | (_| | | | | | | | | (_| | | (_| | |_) | |_) \__ \
|_____/|_|\__, |_| |_|_|_| |_|\__, |  \__,_| .__/| .__/|___/
           __/ |               __/ |       | |   | |
          |___/               |___/        |_|   |_|
'@
Measure-Command {
$apps | Where-Object { $prebuiltApps -notcontains $_ } | ForEach-Object {

    $Parameters = @{
        "containerName" = (GetBuildContainer)
        "appFile" = $_
        "pfxFile" = $codeSignCertPfxFile
        "pfxPassword" = $codeSignCertPfxPassword
        "importCertificate" = $codeSignCertIsSelfSigned -or $isInsideContainer
    }

    Invoke-Command -ScriptBlock $SignBcContainerApp -ArgumentList $Parameters

}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nSigning apps took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
}

$previousAppsInstalled = @()
if (!$useDevEndpoint) {

if ((!$doNotPublishApps) -and ($appsBeforeApps)) {
Write-GroupStart -Message "Publishing app dependencies"
Write-Host -ForegroundColor Yellow @'
  _____       _     _ _     _     _                                       _                           _                 _
 |  __ \     | |   | (_)   | |   (_)                                     | |                         | |               (_)
 | |__) |   _| |__ | |_ ___| |__  _ _ __   __ _    __ _ _ __  _ __     __| | ___ _ __   ___ _ __   __| | ___ _ __   ___ _  ___  ___
 |  ___/ | | | '_ \| | / __| '_ \| | '_ \ / _` |  / _` | '_ \| '_ \   / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| |/ _ \/ __|
 | |   | |_| | |_) | | \__ \ | | | | | | | (_| | | (_| | |_) | |_) | | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |  __/\__ \
 |_|    \__,_|_.__/|_|_|___/_| |_|_|_| |_|\__, |  \__,_| .__/| .__/   \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|_|\___||___/
                                           __/ |       | |   | |                | |
                                          |___/        |_|   |_|                |_|
'@
Measure-Command {

    $Parameters = @{
        "containerName" = (GetBuildContainer)
        "tenant" = $tenant
        "credential" = $credential
        "appFile" = $appsBeforeApps
        "skipVerification" = $true
        "sync" = $true
        "install" = $true
        "upgrade" = $true
        "ignoreIfAppExists" = $true
}
    
    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
            "checkAlreadyInstalled" = $true
        }
    }
    
    if (!$doNotPublishApps) {
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPublishing app dependencies took $([int]$_.TotalSeconds) seconds" }
}

if ((!$doNotPerformUpgrade) -and ($previousApps)) {
Write-GroupStart -Message "Installing previous apps"
Write-Host -ForegroundColor Yellow @'
  _____           _        _ _ _                                    _
 |_   _|         | |      | | (_)                                  (_)
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _   _ __  _ __ _____   ___  ___  _   _ ___    __ _ _ __  _ __  ___
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | | '_ \| '__/ _ \ \ / / |/ _ \| | | / __|  / _` | '_ \| '_ \/ __|
  _| |_| | | \__ \ || (_| | | | | | | | (_| | | |_) | | |  __/\ V /| | (_) | |_| \__ \ | (_| | |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, | | .__/|_|  \___| \_/ |_|\___/ \__,_|___/  \__,_| .__/| .__/|___/
                                        __/ | | |                                            | |   | |
                                       |___/  |_|                                            |_|   |_|
'@
Measure-Command {
    if ($testCountry) {
        Write-Host -ForegroundColor Yellow "Installing previous apps for additional country $testCountry"
    }
    if ($previousApps) {
        $previousApps | ForEach-Object{
            $Parameters = @{
                "containerName" = (GetBuildContainer)
                "tenant" = $tenant
                "credential" = $credential
                "appFile" = $_
                "skipVerification" = $true
                "sync" = $true
                "install" = $true
                "useDevEndpoint" = $false
            }
            if ($bcAuthContext) {
                $Parameters += @{
                    "bcAuthContext" = $bcAuthContext
                    "environment" = $environment
                    "replacePackageId" = $true
                    "checkAlreadyInstalled" = $true
                }
            }
            if (!$doNotPublishApps) {
                Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
            }
        }
        if ($bcAuthContext) {
            Write-Host "Wait for online environment to process apps"
            Start-Sleep -Seconds 30
        }
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}

if ((!$doNotPublishApps) -and ($apps+$testApps+$bcptTestApps)) {
Write-GroupStart -Message "Publishing apps"
Write-Host -ForegroundColor Yellow @'
  _____       _     _ _     _     _
 |  __ \     | |   | (_)   | |   (_)
 | |__) |   _| |__ | |_ ___| |__  _ _ __   __ _    __ _ _ __  _ __  ___
 |  ___/ | | | '_ \| | / __| '_ \| | '_ \ / _` |  / _` | '_ \| '_ \/ __|
 | |   | |_| | |_) | | \__ \ | | | | | | | (_| | | (_| | |_) | |_) \__ \
 |_|    \__,_|_.__/|_|_|___/_| |_|_|_| |_|\__, |  \__,_| .__/| .__/|___/
                                           __/ |       | |   | |
                                          |___/        |_|   |_|
'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Publishing apps for additional country $testCountry"
}

$alreadyInstalledApps = @()
if (!($bcAuthContext)) {
    $Parameters = @{
        "containerName" = (GetBuildContainer)
        "tenant" = $tenant
        "tenantSpecificProperties" = $true
    }
    $alreadyInstalledApps = @(Invoke-Command -ScriptBlock $GetBcContainerAppInfo -ArgumentList $Parameters | Where-Object { $_.IsInstalled })
}

$upgradedApps = @()
$apps | ForEach-Object {

    $installedApp = $false
    if ($apps -contains $_) {
        $folder = $appsFolder[$_]
        $appJsonFile = Join-Path $folder "app.json"
        $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
        $upgradedApps += @($appJson.Id.ToLowerInvariant())

        if ($alreadyInstalledApps | Where-Object { "$($_.AppId)" -eq $appJson.Id }) {
            $installedApp = $true
        }
    }

    $Parameters = @{
        "containerName" = (GetBuildContainer)
        "tenant" = $tenant
        "credential" = $credential
        "appFile" = $_
        "skipVerification" = !$signApps
        "sync" = $true
        "install" = !$installedApp
        "upgrade" = $installedApp
    }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
            "checkAlreadyInstalled" = $true
        }
    }

    if (!$doNotPublishApps) {
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }
}

if ($uninstallRemovedApps -and !$doNotPerformUpgrade) {
    [array]::Reverse($previousAppInfos)
    $previousAppInfos | ForEach-Object {
        if (!$upgradedApps.Contains($_.AppId)) {
            Write-Host "Uninstalling $($_.Name) version $($_.Version) from $($_.Publisher)"
            $Parameters = @{
                "containerName" = (GetBuildContainer)
                "tenant" = $tenant
                "name" = $_.Name
                "publisher" = $_.Publisher
                "version" = $_.Version
                "uninstall" = $true
            }

            if (!$doNotPublishApps) {
                Invoke-Command -ScriptBlock $UnPublishBcContainerApp -ArgumentList $Parameters
            }
        }
    }
}

$appsBeforeTestApps+$testApps+$bcptTestApps | ForEach-Object {

    $Parameters = @{
        "containerName" = (GetBuildContainer)
        "tenant" = $tenant
        "credential" = $credential
        "appFile" = $_
        "skipVerification" = $true
        "sync" = $true
        "install" = $true
        "upgrade" = $true
        "ignoreIfAppExists" = $true
    }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
            "checkAlreadyInstalled" = $true
        }
    }

    if (!$doNotPublishApps) {
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }
}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPublishing apps took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}
}

if ($createContainer -and !($doNotRunTests -and $doNotRunBcptTests -and $doNotRunPageScriptingTests)) {
if ($ImportTestDataInBcContainer) {
Write-GroupStart -Message "Importing test data"
Write-Host -ForegroundColor Yellow @'
  _____                            _   _               _            _         _       _
 |_   _|                          | | (_)             | |          | |       | |     | |
   | |  _ __ ___  _ __   ___  _ __| |_ _ _ __   __ _  | |_ ___  ___| |_    __| | __ _| |_ __ _
   | | | '_ ` _ \| '_ \ / _ \| '__| __| | '_ \ / _` | | __/ _ \/ __| __|  / _` |/ _` | __/ _` |
  _| |_| | | | | | |_) | (_) | |  | |_| | | | | (_| | | ||  __/\__ \ |_  | (_| | (_| | || (_| |
 |_____|_| |_| |_| .__/ \___/|_|   \__|_|_| |_|\__, |  \__\___||___/\__|  \__,_|\__,_|\__\__,_|
                 | |                            __/ |
                 |_|                           |___/
'@
if (!$enableTaskScheduler) {
    Invoke-ScriptInBcContainer -containerName (GetBuildContainer) -scriptblock {
        Write-Host "Enabling Task Scheduler to load configuration packages"
        Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "EnableTaskScheduler" -KeyValue "True" -WarningAction SilentlyContinue
        Set-NAVServerInstance -ServerInstance $ServerInstance -Restart
        while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
            Start-Sleep -Seconds 1
        }
    }
}

$Parameters = @{
    "containerName" = (GetBuildContainer)
    "tenant" = $tenant
    "credential" = $credential
}
Invoke-Command -ScriptBlock $ImportTestDataInBcContainer -ArgumentList $Parameters

if (!$enableTaskScheduler) {
    Invoke-ScriptInBcContainer -containerName (GetBuildContainer) -scriptblock {
        Write-Host "Disabling Task Scheduler again"
        Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "EnableTaskScheduler" -KeyValue "False" -WarningAction SilentlyContinue
        Set-NAVServerInstance -ServerInstance $ServerInstance -Restart
        while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
            Start-Sleep -Seconds 1
        }
    }
}
Write-GroupEnd
}

if ($restoreDatabases) {
Write-GroupStart -Message "Backing up databases"
Invoke-Command -ScriptBlock $BackupBcContainerDatabases -ArgumentList @{"containerName" = (GetBuildContainer)}
Write-GroupEnd
}
}

$allPassed = $true
$resultsFile = Join-Path ([System.IO.Path]::GetDirectoryName($testResultsFile)) "$([System.IO.Path]::GetFileNameWithoutExtension($testResultsFile))$testCountry.xml"
$bcptResultsFile = Join-Path ([System.IO.Path]::GetDirectoryName($bcptTestResultsFile)) "$([System.IO.Path]::GetFileNameWithoutExtension($bcptTestResultsFile))$testCountry.json"
if (!$doNotRunTests -and (($testFolders) -or ($runTestApps))) {
Write-GroupStart -Message "Running tests"
Write-Host -ForegroundColor Yellow @'
  _____                   _               _            _
 |  __ \                 (_)             | |          | |
 | |__) |   _ _ __  _ __  _ _ __   __ _  | |_ ___  ___| |_ ___
 |  _  / | | | '_ \| '_ \| | '_ \ / _` | | __/ _ \/ __| __/ __|
 | | \ \ |_| | | | | | | | | | | | (_| | | ||  __/\__ \ |_\__ \
 |_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, |  \__\___||___/\__|___/
                                   __/ |
                                  |___/
'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Running Tests for additional country $testCountry"
}

$testAppIds = @{}
$runTestApps | ForEach-Object {
    $appId = [Guid]::Empty
    if ([Guid]::TryParse($_, [ref] $appId)) {
        if ($testAppIds.ContainsKey($appId)) {
            Write-Host -ForegroundColor Red "$($appId) already exists in the list of apps to test!"
        }
        else {
            $testAppIds += @{ "$appId" = "" }
        }
    }
    else {
        $appFile = $_
        if ($appFile -eq "$_".Trim('()')) {
            $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            try {
                $appList = CopyAppFilesToFolder -appFiles $_ -folder $tmpFolder
                $appList | ForEach-Object {
                    $appFile = $_
                    $appFolder = "$($_).source"
                    Extract-AppFileToFolder -appFilename $_ -appFolder $appFolder -generateAppJson
                    $appJsonFile = Join-Path $appFolder "app.json"
                    $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
                    if ($testAppIds.ContainsKey($appJson.Id)) {
                        Write-Host -ForegroundColor Red "$($appJson.Id) already exists in the list of apps to test! (do you have the same app twice in installTestApps?)"
                    }
                    else {
                        $testAppIds += @{ "$($appJson.Id)" = "" }
                    }
                }
            }
            catch {
                Write-Host -ForegroundColor Red "Cannot run tests in test app $([System.IO.Path]::GetFileName($appFile)), it might be a runtime package."
            }
            finally {
                Remove-Item $tmpFolder -Recurse -Force
            }
        }
    }
}
$testFolders | ForEach-Object {
    $appJson = [System.IO.File]::ReadAllLines((Join-Path $_ "app.json")) | ConvertFrom-Json
    if ($testAppIds.ContainsKey($appJson.Id)) {
        Write-Host -ForegroundColor Red "$($appJson.Id) already exists in the list of apps to test! (are you installing apps with the same ID as your test apps?)"
        $testAppIds."$($appJson.Id)" = $_
    }
    else {
        $testAppIds += @{ "$($appJson.Id)" = $_ }
    }
}

$installedApps = @(GetInstalledApps -bcAuthContext $bcAuthContext -environment $environment -useCompilerFolder $useCompilerFolder -filesOnly $filesOnly -compilerFolder (GetCompilerFolder) -packagesFolder $packagesFolder)
$testAppIds.Keys | ForEach-Object {
    $disabledTests = @()
    $id = $_
    $installedApp = $installedApps | Where-Object { $_.Id -eq $id }
    if (-not $installedApp) {
        throw "App with $id is not installed, cannot run tests"
    }
    $folder = $testAppIds."$id"

    if ($folder) {
        Write-Host "Running tests for App $id in $folder"
    }
    else {
        Write-Host "Running tests for App $id"
    }
    if ($folder) {
        Get-ChildItem -Path $folder -Filter "disabledTests.json" -Recurse | ForEach-Object {
            $disabledTestsStr = Get-Content $_.FullName -Raw -Encoding utf8
            Write-Host "Disabled Tests:`n$disabledTestsStr"
            $disabledTests += ($disabledTestsStr | ConvertFrom-Json)
        }
    }
    Get-ChildItem -Path $baseFolder -Filter "$id.disabledTests.json" -Recurse | ForEach-Object {
        $disabledTestsStr = Get-Content $_.FullName -Raw -Encoding utf8
        Write-Host "Disabled Tests:`n$disabledTestsStr"
        $disabledTests += ($disabledTestsStr | ConvertFrom-Json)
    }
    $Parameters = @{
        "tenant" = $tenant
        "credential" = $credential
        "companyName" = $companyName
        "extensionId" = $id
        "appName" = $installedApp.Name
        "disabledTests" = $disabledTests
        "AzureDevOps" = "$(if($azureDevOps){if($treatTestFailuresAsWarnings){'warning'}else{'error'}}else{'no'})"
        "GitHubActions" = "$(if($githubActions){if($treatTestFailuresAsWarnings){'warning'}else{'error'}}else{'no'})"
        "detailed" = $true
        "returnTrueIfAllPassed" = $true
    }
    if ($createContainer) {
        $Parameters += @{ "containerName" = (GetBuildContainer) }
    }
    if ($useCompilerFolder) {
        $Parameters += @{ "compilerFolder" = (GetCompilerFolder) }
    }

    if ($testResultsFormat -eq "XUnit") {
        $Parameters += @{
            "XUnitResultFileName" = $resultsFile
            "AppendToXUnitResultFile" = $true
        }
    }
    else {
        $Parameters += @{
            "JUnitResultFileName" = $resultsFile
            "AppendToJUnitResultFile" = $true
        }
    }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
            "ConnectFromHost" = !$createContainer
        }
    }
    if ($restoreDatabases -contains 'BeforeEachTestApp') {
        Write-GroupStart -Message "Restoring databases before test app"
        Invoke-Command -ScriptBlock $RestoreDatabasesInBcContainer -ArgumentList @{"containerName" = (GetBuildContainer)}
        Write-GroupEnd
    }

    if (!(Invoke-Command -ScriptBlock $RunTestsInBcContainer -ArgumentList $Parameters)) {
        $allPassed = $false
    }

}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRunning tests took $([int]$_.TotalSeconds) seconds" }
if ($buildArtifactFolder -and (Test-Path $resultsFile)) {
    Write-Host "Copying test results to output"
    Copy-Item -Path $resultsFile -Destination $buildArtifactFolder -Force
}
Write-GroupEnd
}

if (!$doNotRunBcptTests -and $bcptTestSuites) {
if ($restoreDatabases -contains 'BeforeBcpTests' -and $restoreDatabases -notcontains 'BeforeEachBcptTestApp') {
    Write-GroupStart -Message "Restoring databases before bcpt tests"
    Invoke-Command -ScriptBlock $RestoreDatabasesInBcContainer -ArgumentList @{"containerName" = (GetBuildContainer)}
    Write-GroupEnd
}
Write-GroupStart -Message "Running BCPT tests"
Write-Host -ForegroundColor Yellow @'
  _____                   _               ____   _____ _____ _______   _            _
 |  __ \                 (_)             |  _ \ / ____|  __ \__   __| | |          | |
 | |__) |   _ _ __  _ __  _ _ __   __ _  | |_) | |    | |__) | | |    | |_ ___  ___| |_ ___
 |  _  / | | | '_ \| '_ \| | '_ \ / _` | |  _ <| |    |  ___/  | |    | __/ _ \/ __| __/ __|
 | | \ \ |_| | | | | | | | | | | | (_| | | |_) | |____| |      | |    | ||  __/\__ \ |_\__ \
 |_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, | |____/ \_____|_|      |_|     \__\___||___/\__|___/
                                   __/ |
                                  |___/
'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Running BCPT Tests for additional country $testCountry"
}

$bcptTestSuites | ForEach-Object {
    $Parameters = @{
        "containerName" = (GetBuildContainer)
        "tenant" = $tenant
        "credential" = $credential
        "companyName" = $companyName
        "connectFromHost" = $true
        "BCPTsuite" = [System.IO.File]::ReadAllLines($_) | ConvertFrom-Json
    }

    if ($restoreDatabases -contains 'BeforeEachBcptTestApp') {
        Write-GroupStart -Message "Restoring databases before each bcpt test app"
        Invoke-Command -ScriptBlock $RestoreDatabasesInBcContainer -ArgumentList @{"containerName" = (GetBuildContainer)}
        Write-GroupEnd
    }

    $result = Invoke-Command -ScriptBlock $RunBCPTTestsInBcContainer -ArgumentList $Parameters

    Write-Host "Saving bcpt test results to $bcptResultsFile"
    $result | ConvertTo-Json -Depth 99 | Set-Content $bcptResultsFile
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRunning BCPT tests took $([int]$_.TotalSeconds) seconds" }
if ($buildArtifactFolder -and (Test-Path $bcptResultsFile)) {
    Write-Host "Copying bcpt test results to output"
    Copy-Item -Path $bcptResultsFile -Destination $buildArtifactFolder -Force
}
Write-GroupEnd
}

if ($createContainer -and !$doNotRunPageScriptingTests -and $pageScriptingTests -and $pageScriptingTestResultsFolder -and $pageScriptingTestResultsFile) {
if ($restoreDatabases -contains 'BeforePageScriptingTests' -and $restoreDatabases -notcontains 'BeforeEachPageScriptingTest') {
    Write-GroupStart -Message "Restoring databases before page scripting tests"
    Invoke-Command -ScriptBlock $RestoreDatabasesInBcContainer -ArgumentList @{"containerName" = (GetBuildContainer)}
    Write-GroupEnd
}
Write-GroupStart -Message "Running Page Scripting Tests"
Write-Host -ForegroundColor Yellow @'
 _____                   _               _____                  _____           _       _   _               _______        _
|  __ \                 (_)             |  __ \                / ____|         (_)     | | (_)             |__   __|      | |
| |__) |   _ _ __  _ __  _ _ __   __ _  | |__) |_ _  __ _  ___| (___   ___ _ __ _ _ __ | |_ _ _ __   __ _     | | ___  ___| |_ ___
|  _  / | | | '_ \| '_ \| | '_ \ / _` | |  ___/ _` |/ _` |/ _ \\___ \ / __| '__| | '_ \| __| | '_ \ / _` |    | |/ _ \/ __| __/ __|
| | \ \ |_| | | | | | | | | | | | (_| | | |  | (_| | (_| |  __/____) | (__| |  | | |_) | |_| | | | | (_| |    | |  __/\__ \ |_\__ \
|_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, | |_|   \__,_|\__, |\___|_____/ \___|_|  |_| .__/ \__|_|_| |_|\__, |    |_|\___||___/\__|___/
                                  __/ |              __/ |                       | |                 __/ |
                                 |___/              |___/                        |_|                |___/
'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Running Page Scripting Tests for additional country $testCountry"
}

$containerName = (GetBuildContainer)

# Install npm package for page scripting tests
pwsh -command { npm i @microsoft/bc-replay@0.1.67 --save --silent }

${env:containerUsername} = $credential.UserName
${env:containerPassword} = $credential.Password | Get-PlainText
$startAddress = "http://$containerName/BC?tenant=$tenant"

$usedNames = @()

$pageScriptingTests | ForEach-Object {
    $thisFailed = $false
    if ($restoreDatabases -contains 'BeforeEachPageScriptingTest') {
        Write-GroupStart -Message "Restoring databases before each page scripting test"
        Invoke-Command -ScriptBlock $RestoreDatabasesInBcContainer -ArgumentList @{"containerName" = $containerName}
        Write-GroupEnd
    }
    $testSpec = $_
    $name = $testSpec -replace '[\\/]', '-' -replace ':', '' -replace '\*', 'all' -replace '\?', 'x' -replace '\.yml$', ''
    if ($usedNames -contains $name) {
        throw "PageScriptingTests contains two similar test specs (resulting in identical results folders), please rename your test specs ($testSpec)."
    }
    $usedNames += $name
    $path = $testSpec
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $baseFolder $path }
    if (-not (Test-Path $path)) { throw "No page scripting tests found matching $testSpec" }
    Write-Host "Running Page Scripting Tests for $testSpec (test name: $name)"
    $resultsFolder = Join-Path $pageScriptingTestResultsFolder $name
    New-Item -Path $resultsFolder -ItemType Directory | Out-Null
    pwsh -command {
        npx replay $args[0] -ResultDir $args[1] -StartAddress $args[2] -Authentication UserPassword -usernameKey 'containerUsername' -passwordkey 'containerPassword'
    } -args $path, $resultsFolder, $startAddress
    if ($? -ne "True") {
        Write-Host "Page Scripting Tests failed for $testSpec"
        $allPassed = $false
        $thisFailed = $true
    }
    $testResultsFile = Join-Path $resultsFolder "results.xml"
    $playwrightReportFolder = Join-Path $resultsFolder 'playwright-report'
    if ((Test-Path $testResultsFile -PathType Leaf) -and (Test-Path $playwrightReportFolder -PathType Container)) {
        $thisXml = [xml](Get-Content $testResultsFile -encoding UTF8)
        $thisXml.testsuites.testsuite.Name = $name
        $resultsXml = $thisXml
        if (Test-Path $pageScriptingTestResultsFile) {
            # Merge results and aggregate counts
            $resultsXml = [xml](Get-Content $pageScriptingTestResultsFile -encoding UTF8)
            $resultsXml.testsuites.AppendChild($resultsXml.ImportNode($thisXml.testsuites.testsuite, $true))
        }
        foreach($property in 'tests','failures','skipped','errors','time') {
            $resultsXml.testsuites."$property" = "$(([double[]]$resultsXml.testsuites.testsuite."$property" | Measure-Object -Sum).Sum)"
        }
        $resultsXml.Save($pageScriptingTestResultsFile)
        Remove-Item $testResultsFile -Force
        if ($thisFailed) {
            Write-Host "Moving Playwright report folder"
            Move-Item -Path "$playwrightReportFolder/*" -Destination $resultsFolder -Force
            Write-Host "Removing Playwright report folder"
            Remove-Item -Path $playwrightReportFolder -Force
        }
        else {
            Write-Host "Removing results folder"
            Remove-Item -Path $resultsFolder -Recurse -Force
        }
    }
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRunning Page Scripting Tests took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}

if (($gitLab -or $gitHubActions) -and !$allPassed) {
    if (-not $treatTestFailuresAsWarnings) {
        throw "There are test failures!"
    }
}
}

if ($buildArtifactFolder) {
Write-GroupStart -Message "Copy to build artifacts"
Write-Host -ForegroundColor Yellow @'
  _____                     _          _           _ _     _              _   _  __           _
 / ____|                   | |        | |         (_) |   | |            | | (_)/ _|         | |
 | |     ___  _ __  _   _  | |_ ___   | |__  _   _ _| | __| |   __ _ _ __| |_ _| |_ __ _  ___| |_ ___
 | |    / _ \| '_ \| | | | | __/ _ \  | '_ \| | | | | |/ _` |  / _` | '__| __| |  _/ _` |/ __| __/ __|
 | |___| (_) | |_) | |_| | | || (_) | | |_) | |_| | | | (_| | | (_| | |  | |_| | || (_| | (__| |_\__ \
 \______\___/| .__/ \__, |  \__\___/  |_.__/ \__,_|_|_|\__,_|  \__,_|_|   \__|_|_| \__,_|\___|\__|___/
             | |     __/ |
             |_|    |___/
'@

Measure-Command {

$destFolder = Join-Path $buildArtifactFolder "Apps"
if (!(Test-Path $destFolder -PathType Container)) {
    New-Item $destFolder -ItemType Directory | Out-Null
}
$apps | Where-Object { $prebuiltApps -notcontains $_ } | ForEach-Object {
    Copy-Item -Path $_ -Destination $destFolder -Force
}
$destFolder = Join-Path $buildArtifactFolder "TestApps"
if (!(Test-Path $destFolder -PathType Container)) {
    New-Item $destFolder -ItemType Directory | Out-Null
}
$testApps+$bcptTestApps | Where-Object { $prebuiltApps -notcontains $_ } | ForEach-Object {
    Copy-Item -Path $_ -Destination $destFolder -Force
}

if ($createRuntimePackages) {
    $destFolder = Join-Path $buildArtifactFolder "RuntimePackages"
    if (!(Test-Path $destFolder -PathType Container)) {
        New-Item $destFolder -ItemType Directory | Out-Null
    }
    $no = 1
    $apps | ForEach-Object {
        $appFile = $_
        $tempRuntimeAppFile = "$($appFile.TrimEnd('.app')).runtime.app"
        $folder = $appsFolder[$appFile]
        $appJson = [System.IO.File]::ReadAllLines((Join-Path $folder "app.json")) | ConvertFrom-Json
        Write-Host "Getting Runtime Package for $([System.IO.Path]::GetFileName($appFile))"

        $Parameters = @{
            "containerName" = (GetBuildContainer)
            "tenant" = $tenant
            "appName" = $appJson.name
            "appVersion" = $appJson.Version
            "publisher" = $appJson.Publisher
            "appFile" = $tempRuntimeAppFile
        }

        Invoke-Command -ScriptBlock $GetBcContainerAppRuntimePackage -ArgumentList $Parameters

        if ($signApps) {
            Write-Host "Signing runtime package"
            $Parameters = @{
                "containerName" = (GetBuildContainer)
                "appFile" = $tempRuntimeAppFile
                "pfxFile" = $codeSignCertPfxFile
                "pfxPassword" = $codeSignCertPfxPassword
            }

            Invoke-Command -ScriptBlock $SignBcContainerApp -ArgumentList $Parameters
        }

        Write-Host "Copying runtime package to build artifact"
        Copy-Item -Path $tempRuntimeAppFile -Destination (Join-Path $destFolder "$($no.ToString('00')) - $([System.IO.Path]::GetFileName($tempRuntimeAppFile))" ) -Force
        $no++
    }
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCopying to Build Artifacts took $([int]$_.TotalSeconds) seconds" }
Write-GroupEnd
}

} catch {
    $err = $_
}
finally {
    $progressPreference = $prevProgressPreference
    ${env:containerPassword} = $null
}

if ($buildArtifactFolder) {
    Write-GroupStart -Message "Files in build artifacts folder:"
    Get-ChildItem $buildArtifactFolder -Recurse | Where-Object {!$_.PSIsContainer} | ForEach-Object { Write-Host "$($_.FullName.Substring($buildArtifactFolder.Length+1)) ($($_.Length) bytes)" }
    Write-GroupEnd
}

if ($useCompilerFolder) {
    RemoveCompilerFolder
}

if ($createContainer -and !$keepContainer) {
Write-GroupStart -Message "Removing container"
if (!($err)) {
Write-Host -ForegroundColor Yellow @'
  _____                           _                               _        _
 |  __ \                         (_)                             | |      (_)
 | |__) |___ _ __ ___   _____   ___ _ __   __ _    ___ ___  _ __ | |_ __ _ _ _ __   ___ _ __
 |  _  // _ \ '_ ` _ \ / _ \ \ / / | '_ \ / _` |  / __/ _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | | \ \  __/ | | | | | (_) \ V /| | | | | (_| | | (_| (_) | | | | || (_| | | | | |  __/ |
 |_|  \_\___|_| |_| |_|\___/ \_/ |_|_| |_|\__, |  \___\___/|_| |_|\__\__,_|_|_| |_|\___|_|
                                           __/ |
                                          |___/
'@
}
Measure-Command {

    if (!$doNotPublishApps -and ($script:existingContainerName)) {
        $containerName = GetBuildContainer
        if ($containerName) {
            if (!$filesOnly -and $containerEventLogFile) {
                try {
                    Write-Host "Get Event Log from container"
                    $Parameters = @{
                        "containerName" = $containerName
                        "doNotOpen" = $true
                    }
                    $eventlogFile = Invoke-Command -ScriptBlock $GetBcContainerEventLog -ArgumentList $Parameters
                    Copy-Item -Path $eventLogFile -Destination $containerEventLogFile
                }
                catch {}
            }
            RemoveBuildContainer
        }
    }
} | ForEach-Object { if (!($err)) { Write-Host -ForegroundColor Yellow "`nRemoving container took $([int]$_.TotalSeconds) seconds" } }
Write-GroupEnd
}

if ($warningsToShow) {
    ($warningsToShow -join "`n") | Write-Host -ForegroundColor Yellow
}

if ($err) {
    throw $err
}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nAL Pipeline finished in $([int]$_.TotalSeconds) seconds" }

if ($PipelineFinalize) {
    Invoke-Command -ScriptBlock $PipelineFinalize
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
Export-ModuleMember -Function Run-AlPipeline
