<# 
 .Synopsis
  Run AL Pipeline
 .Description
  Run AL Pipeline
 .Parameter pipelineName
  The name of the pipeline or project.
 .Parameter baseFolder
  The baseFolder serves as the base Folder for all other parameters including a path (appFolders, testFolders, testResultFile, outputFolder, packagesFolder and buildArtifactsFodler).
 .Parameter licenseFile
  License file to use for AL Pipeline.
 .Parameter containerName
  This is the containerName going to be used for the build/test container. If not specified, the container name will be the pipeline name followed by -bld.
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
 .Parameter credential
  These are the credentials used for the container. If not provided, the Run-AlPipeline function will generate a random password and use that.
 .Parameter codeSignCertPfxFile
  A secure url to a code signing certificate for signing apps. Apps will only be signed if useDevEndpoint is NOT specified.
 .Parameter codeSignCertPfxPassword
  Password for the code signing certificate specified by codeSignCertPfxFile. Apps will only be signed if useDevEndpoint is NOT specified.
 .Parameter installApps
  Array or comma separated list of 3rd party apps to install before compiling apps.
 .Parameter installTestApps
  Array or comma separated list of 3rd party apps to install before compiling test apps.
 .Parameter previousApps
  Array or comma separated list of previous version of apps
 .Parameter appFolders
  Array or comma separated list of folders with apps to be compiled, signed and published
 .Parameter testFolders
  Array or comma separated list of folders with test apps to be compiled, published and run
 .Parameter additionalCountries
  Array or comma separated list of countries to test
 .Parameter appBuild
  Build number for build. Will be stamped into the build part of the app.json version number property.
 .Parameter appRevision
  Revision number for build. Will be stamped into the revision part of the app.json version number property.
 .Parameter applicationInsightsKey
  ApplicationInsightsKey to be stamped into app.json for all apps
 .Parameter testResultsFile
  Filename in which you want the test results to be written. Default is TestResults.xml, meaning that test results will be written to this filename in the base folder. This parameter is ignored if doNotRunTests is included.
 .Parameter testResultsFormat
  Format of test results file. Possible values are XUnit or JUnit. Both formats are XML based test result formats.
 .Parameter packagesFolder
  This is the folder (relative to base folder) where symbols are downloaded  and compiled apps are placed. Only relevant when not using useDevEndpoint.
 .Parameter outputFolder
  This is the folder (relative to base folder) where compiled apps are placed. Only relevant when not using useDevEndpoint.
 .Parameter artifact
  The description of which artifact to use. This can either be a URL (from Get-BcArtifactUrl) or in the format storageAccount/type/version/country/select/sastoken, where these values are transferred as parameters to Get-BcArtifactUrl. Default value is ///us/current.
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
 .Parameter useDevEndpoint
  Including the useDevEndpoint switch will cause the pipeline to publish apps through the development endpoint (like VS Code). This should ONLY be used when running the pipeline locally and will cause some changes in how things are done.
 .Parameter doNotRunTests
  Include this switch to indicate that you do not want to execute tests. Test Apps will still be published and installed, test execution can later be performed from the UI.
 .Parameter keepContainer
  Including the keepContainer switch causes the container to not be deleted after the pipeline finishes.
 .Parameter updateLaunchJson
  Specifies the name of the configuration in launch.json, which should be updated with container information to be able to start debugging right away.
 .Parameter vsixFile
  Specify a URL or path to a .vsix file in order to override the .vsix file in the image with this.
  Use Get-LatestAlLanguageExtensionUrl to get latest AL Language extension from Marketplace.
  Use Get-AlLanguageExtensionFromArtifacts -artifactUrl (Get-BCArtifactUrl -select NextMajor -sasToken $insiderSasToken) to get latest insider .vsix
 .Parameter enableCodeCop
  Include this switch to include Code Cop Rules during compilation.
 .Parameter enableAppSourceCop
  Only relevant for AppSource apps. Include this switch to include AppSource Cop during compilation.
 .Parameter enableUICop
  Include this switch to include UI Cop during compilation.
 .Parameter enablePerTenantExtensionCop
  Only relevant for Per Tenant Extensions. Include this switch to include Per Tenant Extension Cop during compilation.
 .Parameter useDefaultAppSourceRuleSet
  Apply the default ruleset for passing AppSource validation
 .Parameter rulesetFile
  Filename of the custom ruleset file
 .Parameter preProcessorSymbols
  PreProcessorSymbols to set when compiling the app.
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
 .Parameter DockerPull
  Override function parameter for docker pull
 .Parameter NewBcContainer
  Override function parameter for New-BcContainer
 .Parameter ImportTestToolkitToBcContainer
  Override function parameter for Import-TestToolkitToBcContainer
 .Parameter CompileAppInBcContainer
  Override function parameter for Compile-AppInBcContainer
 .Parameter GetBcContainerAppInfo
  Override function parameter for Get-BcContainerAppInfo
 .Parameter PublishBcContainerApp
  Override function parameter for Publish-BcContainerApp
 .Parameter SignBcContainerApp
  Override function parameter for Sign-BcContainerApp
 .Parameter RunTestsInBcContainer
  Override function parameter for Run-TestsInBcContainer
 .Parameter GetBcContainerAppRuntimePackage
  Override function parameter Get-BcContainerAppRuntimePackage
 .Parameter RemoveBcContainer
  Override function parameter for Remove-BcContainer
 .Example
  Please visit https://www.freddysblog.com for descriptions
 .Example
  Please visit https://dev.azure.com/businesscentralapps/HelloWorld for Per Tenant Extension example
 .Example
  Please visit https://dev.azure.com/businesscentralapps/HelloWorld.AppSource for AppSource example

#>
function Run-AlPipeline {
Param(
    [string] $pipelineName,
    [string] $baseFolder = "",
    [string] $licenseFile,
    [string] $containerName = "$($pipelineName.Replace('.','-') -replace '[^a-zA-Z0-9---]', '')-bld".ToLowerInvariant(),
    [string] $imageName = 'my',
    [switch] $enableTaskScheduler,
    [switch] $assignPremiumPlan,
    [string] $tenant = "default",
    [string] $memoryLimit,
    [PSCredential] $credential,
    [string] $codeSignCertPfxFile = "",
    [SecureString] $codeSignCertPfxPassword = $null,
    $installApps = @(),
    $installTestApps = @(),
    $previousApps = @(),
    $appFolders = @("app", "application"),
    $testFolders = @("test", "testapp"),
    $additionalCountries = @(),
    [int] $appBuild = 0,
    [int] $appRevision = 0,
    [string] $applicationInsightsKey,
    [string] $testResultsFile = "TestResults.xml",
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
    [switch] $azureDevOps,
    [switch] $gitLab,
    [switch] $gitHubActions,
    [ValidateSet('none','error','warning')]
    [string] $failOn = "none",
    [switch] $useDevEndpoint,
    [switch] $doNotRunTests,
    [switch] $keepContainer,
    [string] $updateLaunchJson = "",
    [string] $vsixFile = "",
    [switch] $enableCodeCop,
    [switch] $enableAppSourceCop,
    [switch] $enableUICop,
    [switch] $enablePerTenantExtensionCop,
    [switch] $useDefaultAppSourceRuleSet,
    [string] $rulesetFile = "",
    [string[]] $preProcessorSymbols = @(),
    [switch] $escapeFromCops,
    [Hashtable] $bcAuthContext,
    [string] $environment,
    $AppSourceCopMandatoryAffixes = @(),
    $AppSourceCopSupportedCountries = @(),
    [scriptblock] $DockerPull,
    [scriptblock] $NewBcContainer,
    [scriptblock] $ImportTestToolkitToBcContainer,
    [scriptblock] $CompileAppInBcContainer,
    [scriptblock] $GetBcContainerAppInfo,
    [scriptblock] $PublishBcContainerApp,
    [scriptblock] $SignBcContainerApp,
    [scriptblock] $ImportTestDataInBcContainer,
    [scriptblock] $RunTestsInBcContainer,
    [scriptblock] $GetBcContainerAppRuntimePackage,
    [scriptblock] $RemoveBcContainer
)

function CheckRelativePath([string] $baseFolder, $path, $name) {
    if ($path) {
        if (!$path.contains(':')) {
            $path = Join-Path $baseFolder $path
        }
        else {
            if ($path -notlike "$($baseFolder)*") {
                throw "$name is ($path) must be a subfolder to baseFolder ($baseFolder)"
            }
        }
    }
    $path
}

Function UpdateLaunchJson {
    Param(
        [string] $launchJsonFile,
        [System.Collections.Specialized.OrderedDictionary] $launchSettings
    )

    if (Test-Path $launchJsonFile) {
        Write-Host "Modifying $launchJsonFile"
        $launchSettings | ConvertTo-Json | Out-Host
        $launchJson = Get-Content $LaunchJsonFile | ConvertFrom-Json
        $oldSettings = $launchJson.configurations | Where-Object { $_.name -eq $launchsettings.name }
        if ($oldSettings) {
            $oldSettings.PSObject.Properties | % {
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
}

if (!$baseFolder -or !(Test-Path $baseFolder -PathType Container)) {
    throw "baseFolder must be an existing folder"
}

if ($memoryLimit -eq "") {
    $memoryLimit = "8G"
}

if ($installApps                    -is [String]) { $installApps = @($installApps.Split(',').Trim() | Where-Object { $_ }) }
if ($installTestApps                -is [String]) { $installTestApps = @($installTestApps.Split(',').Trim() | Where-Object { $_ }) }
if ($previousApps                   -is [String]) { $previousApps = @($previousApps.Split(',').Trim() | Where-Object { $_ }) }
if ($appFolders                     -is [String]) { $appFolders = @($appFolders.Split(',').Trim()  | Where-Object { $_ }) }
if ($testFolders                    -is [String]) { $testFolders = @($testFolders.Split(',').Trim() | Where-Object { $_ }) }
if ($additionalCountries            -is [String]) { $additionalCountries = @($additionalCountries.Split(',').Trim() | Where-Object { $_ }) }
if ($AppSourceCopMandatoryAffixes   -is [String]) { $AppSourceCopMandatoryAffixes = @($AppSourceCopMandatoryAffixes.Split(',').Trim() | Where-Object { $_ }) }
if ($AppSourceCopSupportedCountries -is [String]) { $AppSourceCopSupportedCountries = @($AppSourceCopSupportedCountries.Split(',').Trim() | Where-Object { $_ }) }

$appFolders  = @($appFolders  | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -path $_ -name "appFolders" } | Where-Object { Test-Path $_ } )
$testFolders = @($testFolders | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -path $_ -name "testFolders" } | Where-Object { Test-Path $_ } )
$testResultsFile = CheckRelativePath -baseFolder $baseFolder -path $testResultsFile -name "testResultsFile"
$rulesetFile = CheckRelativePath -baseFolder $baseFolder -path $rulesetFile -name "rulesetFile"
if (Test-Path $testResultsFile) {
    Remove-Item -Path $testResultsFile -Force
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
    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.name -eq $environment -and $_.type -eq "Sandbox" }
    if (!($bcEnvironment)) {
        throw "Environment $environment doesn't exist in the current context or it is not a Sandbox environment."
    }
    $bcBaseApp = Get-BcPublishedApps -bcAuthContext $bcauthcontext -environment $environment | Where-Object { $_.Name -eq "Base Application" -and $_.state -eq "installed" }
    $artifactUrl = Get-BCArtifactUrl -type Sandbox -country $bcEnvironment.countryCode -version $bcBaseApp.Version -select Closest
    $filesOnly = $true
}

if ($updateLaunchJson) {
    if (!$useDevEndpoint) {
        throw "UpdateLaunchJson cannot be specified if not using DevEndpoint"
    }
}

if ($useDevEndpoint) {
    $packagesFolder = ""
    $outputFolder = ""
}
else {
    $packagesFolder = CheckRelativePath -baseFolder $baseFolder -path $packagesFolder -name "packagesFolder"
    if (Test-Path $packagesFolder) {
        Remove-Item $packagesFolder -Recurse -Force
    }

    $outputFolder = CheckRelativePath -baseFolder $baseFolder -path $outputFolder -name "outputFolder"
    if (Test-Path $outputFolder) {
        Remove-Item $outputFolder -Recurse -Force
    }
}

if ($buildArtifactFolder) {
    if (!(Test-Path $buildArtifactFolder)) {
        New-Item $buildArtifactFolder -ItemType Directory | Out-Null
    }
}

if (!($appFolders)) {
    throw "No app folders found"
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
    $sasToken = $segments[5]

    Write-Host "Determining artifacts to use"
    $minsto = $storageAccount
    $minsel = $select
    $mintok = $sasToken
    if ($additionalCountries) {
        $minver = $null
        @($country)+$additionalCountries | ForEach-Object {
            $url = Get-BCArtifactUrl -storageAccount $storageAccount -type $type -version $version -country $_.Trim() -select $select -sasToken $sasToken | Select-Object -First 1
            Write-Host "Found $($url.Split('?')[0])"
            if ($url) {
                $ver = [Version]$url.Split('/')[4]
                if ($minver -eq $null -or $ver -lt $minver) {
                    $minver = $ver
                    $minsto = $url.Split('/')[2].Split('.')[0]
                    $minsel = "Latest"
                    $mintok = $url.Split('?')[1]; if ($mintok) { $mintok = "?$mintok" }
                }
            }
        }
        if ($minver -eq $null) {
            throw "Unable to locate artifacts"
        }
        $version = $minver.ToString()
    }
    $artifactUrl = Get-BCArtifactUrl -storageAccount $minsto -type $type -version $version -country $country -select $minsel -sasToken $mintok | Select-Object -First 1
    if (!($artifactUrl)) {
        throw "Unable to locate artifacts"
    }
}

$escapeFromCops = $escapeFromCops -and ($enableCodeCop -or $enableAppSourceCop -or $enableUICop -or $enablePerTenantExtensionCop)

Write-Host -ForegroundColor Yellow @'
  _____                               _                
 |  __ \                             | |               
 | |__) |_ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___ 
 |  ___/ _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
 | |  | (_| | | | (_| | | | | | |  __/ |_  __/ |  \__ \
 |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/

'@
Write-Host -NoNewLine -ForegroundColor Yellow "Pipeline name               "; Write-Host $pipelineName
Write-Host -NoNewLine -ForegroundColor Yellow "Container name              "; Write-Host $containerName
Write-Host -NoNewLine -ForegroundColor Yellow "Image name                  "; Write-Host $imageName
Write-Host -NoNewLine -ForegroundColor Yellow "ArtifactUrl                 "; Write-Host $artifactUrl.Split('?')[0]
Write-Host -NoNewLine -ForegroundColor Yellow "SasToken                    "; if ($artifactUrl.Contains('?')) { Write-Host "Specified" } else { Write-Host "Not Specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "BcAuthContext               "; if ($bcauthcontext) { Write-Host "Specified" } else { Write-Host "Not Specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "Environment                 "; Write-Host $environment
Write-Host -NoNewLine -ForegroundColor Yellow "Credential                  ";
if ($credential) {
    Write-Host "Specified"
}
else {
    $password = GetRandomPassword
    Write-Host "admin/$password"
    $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
Write-Host -NoNewLine -ForegroundColor Yellow "MemoryLimit                 "; Write-Host $memoryLimit
Write-Host -NoNewLine -ForegroundColor Yellow "Enable Task Scheduler       "; Write-Host $enableTaskScheduler
Write-Host -NoNewLine -ForegroundColor Yellow "Assign Premium Plan         "; Write-Host $assignPremiumPlan
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Runner         "; Write-Host $installTestRunner
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Framework      "; Write-Host $installTestFramework
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Libraries      "; Write-Host $installTestLibraries
Write-Host -NoNewLine -ForegroundColor Yellow "Install Perf. Toolkit       "; Write-Host $installPerformanceToolkit
Write-Host -NoNewLine -ForegroundColor Yellow "CopySymbolsFromContainer    "; Write-Host $CopySymbolsFromContainer
Write-Host -NoNewLine -ForegroundColor Yellow "enableCodeCop               "; Write-Host $enableCodeCop
Write-Host -NoNewLine -ForegroundColor Yellow "enableAppSourceCop          "; Write-Host $enableAppSourceCop
Write-Host -NoNewLine -ForegroundColor Yellow "enableUICop                 "; Write-Host $enableUICop
Write-Host -NoNewLine -ForegroundColor Yellow "enablePerTenantExtensionCop "; Write-Host $enablePerTenantExtensionCop
Write-Host -NoNewLine -ForegroundColor Yellow "escapeFromCops              "; Write-Host $escapeFromCops
Write-Host -NoNewLine -ForegroundColor Yellow "useDefaultAppSourceRuleSet  "; Write-Host $useDefaultAppSourceRuleSet
Write-Host -NoNewLine -ForegroundColor Yellow "rulesetFile                 "; Write-Host $rulesetFile
Write-Host -NoNewLine -ForegroundColor Yellow "azureDevOps                 "; Write-Host $azureDevOps
Write-Host -NoNewLine -ForegroundColor Yellow "License file                "; if ($licenseFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertPfxFile         "; if ($codeSignCertPfxFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFile             "; Write-Host $testResultsFile
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFormat           "; Write-Host $testResultsFormat
Write-Host -NoNewLine -ForegroundColor Yellow "AdditionalCountries         "; Write-Host ([string]::Join(',',$additionalCountries))
Write-Host -NoNewLine -ForegroundColor Yellow "PackagesFolder              "; Write-Host $packagesFolder
Write-Host -NoNewLine -ForegroundColor Yellow "OutputFolder                "; Write-Host $outputFolder
Write-Host -NoNewLine -ForegroundColor Yellow "BuildArtifactFolder         "; Write-Host $buildArtifactFolder
Write-Host -NoNewLine -ForegroundColor Yellow "CreateRuntimePackages       "; Write-Host $createRuntimePackages
Write-Host -NoNewLine -ForegroundColor Yellow "AppBuild                    "; Write-Host $appBuild
Write-Host -NoNewLine -ForegroundColor Yellow "AppRevision                 "; Write-Host $appRevision
if ($enableAppSourceCop) {
    Write-Host -NoNewLine -ForegroundColor Yellow "Mandatory Affixes           "; Write-Host ($AppSourceCopMandatoryAffixes -join ',')
    Write-Host -NoNewLine -ForegroundColor Yellow "Supported Countries         "; Write-Host ($AppSourceCopSupportedCountries -join ',')
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

if ($DockerPull) {
    Write-Host -ForegroundColor Yellow "DockerPull override"; Write-Host $DockerPull.ToString()
}
else {
    $DockerPull = { Param($imageName) docker pull $imageName }
}
if ($NewBcContainer) {
    Write-Host -ForegroundColor Yellow "NewBccontainer override"; Write-Host $NewBcContainer.ToString()
}
else {
    $NewBcContainer = { Param([Hashtable]$parameters) New-BcContainer @parameters; Invoke-ScriptInBcContainer $parameters.ContainerName -scriptblock { $progressPreference = 'SilentlyContinue' } }
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
if ($SignBcContainerApp) {
    Write-Host -ForegroundColor Yellow "SignBcContainerApp override"; Write-Host $SignBcContainerApp.ToString()
}
else {
    $SignBcContainerApp = { Param([Hashtable]$parameters) Sign-BcContainerApp @parameters }
}
if ($ImportTestDataInBcContainer) {
    Write-Host -ForegroundColor Yellow "ImportTestDataInBcContainer override"; Write-Host $ImportTestDataInBcContainer.ToString()
}
if ($RunTestsInBcContainer) {
    Write-Host -ForegroundColor Yellow "RunTestsInBcContainer override"; Write-Host $RunTestsInBcContainer.ToString()
}
else {
    $RunTestsInBcContainer = { Param([Hashtable]$parameters) Run-TestsInBcContainer @parameters }
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

$signApps = ($codeSignCertPfxFile -ne "")

Measure-Command {

Measure-Command {

if ($artifactUrl) {
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

if (!$useGenericImage) {
    $useGenericImage = Get-BestGenericImageName -filesOnly:$filesOnly
}

Write-Host "Pulling $useGenericImage"

Invoke-Command -ScriptBlock $DockerPull -ArgumentList $useGenericImage
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPulling generic image took $([int]$_.TotalSeconds) seconds" }

$error = $null
$prevProgressPreference = $progressPreference
$progressPreference = 'SilentlyContinue'

try {

@("")+$additionalCountries | % {
$testCountry = $_.Trim()

Write-Host -ForegroundColor Yellow @'

   _____                _   _                               _        _                 
  / ____|              | | (_)                             | |      (_)                
 | |     _ __ ___  __ _| |_ _ _ __   __ _    ___ ___  _ __ | |_ __ _ _ _ __   ___ _ __ 
 | |    | '__/ _ \/ _` | __| | '_ \ / _` |  / __/ _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | |____| | |  __/ (_| | |_| | | | | (_| | | (__ (_) | | | | |_ (_| | | | | |  __/ |   
  \_____|_|  \___|\__,_|\__|_|_| |_|\__, |  \___\___/|_| |_|\__\__,_|_|_| |_|\___|_|   
                                     __/ |                                             
                                    |___/                                              

'@

Measure-Command {

    if ($testCountry) {
        $artifactSegments = $artifactUrl.Split('?')[0].Split('/')
        $artifactUrl = $artifactUrl.Replace("/$($artifactSegments[4])/$($artifactSegments[5])","/$($artifactSegments[4])/$testCountry")
        Write-Host -ForegroundColor Yellow "Creating container for additional country $testCountry"
    }

    $Parameters = @{}
    $useExistingContainer = $false

    if ($bcAuthContext) {
        if (Test-BcContainer -containerName $containerName) {
            if ($artifactUrl -eq (Get-BcContainerArtifactUrl -containerName $containerName)) {
                $useExistingContainer = ((Get-BcContainerPath -containerName $containerName -path $baseFolder) -ne "")
            }
        }
        $Parameters += @{
            "FilesOnly" = $filesOnly
        }
    }

    $Parameters += @{
        "accept_eula" = $true
        "containerName" = $containerName
        "imageName" = $imageName
        "artifactUrl" = $artifactUrl
        "useGenericImage" = $useGenericImage
        "Credential" = $credential
        "auth" = 'UserPassword'
        "vsixFile" = $vsixFile
        "updateHosts" = $true
        "licenseFile" = $licenseFile
        "EnableTaskScheduler" = $enableTaskScheduler
        "AssignPremiumPlan" = $assignPremiumPlan
        "MemoryLimit" = $memoryLimit
        "additionalParameters" = @("--volume ""$($baseFolder):c:\sources""")
    }

    if ($useExistingContainer) {
        Write-Host "Reusing existing container"
    }
    else {
        Invoke-Command -ScriptBlock $NewBcContainer -ArgumentList $Parameters
    }

    if ($tenant -ne 'default' -and -not (Get-BcContainerTenants -containerName $containerName | Where-Object { $_.id -eq "default" })) {

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
        Get-BcContainerAppInfo -containerName $containerName -tenant "default" -tenantSpecificProperties -sort DependenciesFirst | Where-Object { $_.IsInstalled } | % {
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

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCreating container took $([int]$_.TotalSeconds) seconds" }

if ($installApps) {
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

    $installApps | ForEach-Object{
        $Parameters = @{
            "containerName" = $containerName
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $_
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
            }
        }
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
}

if ($testCountry  -and ($installTestRunner -or $installTestFramework -or $installTestLibraries -or $installPerformanceToolkit)) {
Write-Host -ForegroundColor Yellow @'
  _____                            _   _               _______       _     _______          _ _    _ _   
 |_   _|                          | | (_)             |__   __|     | |   |__   __|        | | |  (_) |  
   | |  _ __ ___  _ __   ___  _ __| |_ _ _ __   __ _     | | ___ ___| |_     | | ___   ___ | | | ___| |_ 
   | | | '_ ` _ \| '_ \ / _ \| '__| __| | '_ \ / _` |    | |/ _ \ __| __|    | |/ _ \ / _ \| | |/ / | __|
  _| |_| | | | | | |_) | (_) | |  | |_| | | | | (_| |    | |  __\__ \ |_     | | (_) | (_) | |   <| | |_ 
 |_____|_| |_| |_| .__/ \___/|_|   \__|_|_| |_|\__, |    |_|\___|___/\__|    |_|\___/ \___/|_|_|\_\_|\__|
                 | |                            __/ |                                                    
                 |_|                           |___/                                                     
'@
Measure-Command {
    Write-Host -ForegroundColor Yellow "Importing Test Toolkit for additional country $testCountry"
    $Parameters = @{
        "containerName" = $containerName
        "includeTestLibrariesOnly" = $installTestLibraries
        "includeTestFrameworkOnly" = !$installTestLibraries -and ($installTestFramework -or $installPerformanceToolkit)
        "includeTestRunnerOnly" = !$installTestLibraries -and !$installTestFramework -and ($installTestRunner -or $installPerformanceToolkit)
        "includePerformanceToolkit" = $installPerformanceToolkit
        "doNotUseRuntimePackages" = $true
    }
    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
        }
    }
    Invoke-Command -ScriptBlock $ImportTestToolkitToBcContainer -ArgumentList $Parameters
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nImporting Test Toolkit took $([int]$_.TotalSeconds) seconds" }

if ($installTestApps) {
Write-Host -ForegroundColor Yellow @'

  _____           _        _ _ _               _______       _                              
 |_   _|         | |      | | (_)             |__   __|     | |       /\                    
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _     | | ___ ___| |_     /  \   _ __  _ __  ___ 
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` |    | |/ _ \ __| __|   / /\ \ | '_ \| '_ \/ __|
  _| |_| | | \__ \ |_ (_| | | | | | | | (_| |    | |  __\__ \ |_   / ____ \| |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |    |_|\___|___/\__| /_/    \_\ .__/| .__/|___/
                                        __/ |                              | |   | |        
                                       |___/                               |_|   |_|        

'@
Measure-Command {

    if ($testCountry) {
        Write-Host -ForegroundColor Yellow "Installing test apps for additional country $testCountry"
    }

    $installTestApps | ForEach-Object{
        $Parameters = @{
            "containerName" = $containerName
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $_
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
            }
        }
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling testapps took $([int]$_.TotalSeconds) seconds" }
}

}
else {
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
$measureText = ""
Measure-Command {
$previousAppsCopied = $false
$appsFolder = @{}
$apps = @()
$testApps = @()
$testToolkitInstalled = $false
$sortedFolders = @(Sort-AppFoldersByDependencies -appFolders $appFolders -WarningAction SilentlyContinue) + 
                 @(Sort-AppFoldersByDependencies -appFolders $testFolders -WarningAction SilentlyContinue)
$sortedFolders | Select-Object -Unique | ForEach-Object {
    $folder = $_

    $testApp = $testFolders.Contains($folder)
    $app = $appFolders.Contains($folder)

    if ($testApp -and !$testToolkitInstalled -and ($installTestRunner -or $installTestFramework -or $installTestLibraries -or $installPerformanceToolkit)) {

Write-Host -ForegroundColor Yellow @'
  _____                            _   _               _______       _     _______          _ _    _ _   
 |_   _|                          | | (_)             |__   __|     | |   |__   __|        | | |  (_) |  
   | |  _ __ ___  _ __   ___  _ __| |_ _ _ __   __ _     | | ___ ___| |_     | | ___   ___ | | | ___| |_ 
   | | | '_ ` _ \| '_ \ / _ \| '__| __| | '_ \ / _` |    | |/ _ \ __| __|    | |/ _ \ / _ \| | |/ / | __|
  _| |_| | | | | | |_) | (_) | |  | |_| | | | | (_| |    | |  __\__ \ |_     | | (_) | (_) | |   <| | |_ 
 |_____|_| |_| |_| .__/ \___/|_|   \__|_|_| |_|\__, |    |_|\___|___/\__|    |_|\___/ \___/|_|_|\_\_|\__|
                 | |                            __/ |                                                    
                 |_|                           |___/                                                     
'@
Measure-Command {
        $measureText = ", test apps and importing test toolkit"
        $Parameters = @{
            "containerName" = $containerName
            "includeTestLibrariesOnly" = $installTestLibraries
            "includeTestFrameworkOnly" = !$installTestLibraries -and ($installTestFramework -or $installPerformanceToolkit)
            "includeTestRunnerOnly" = !$installTestLibraries -and !$installTestFramework -and ($installTestRunner -or $installPerformanceToolkit)
            "includePerformanceToolkit" = $installPerformanceToolkit
            "doNotUseRuntimePackages" = $true
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
            }
        }
        Invoke-Command -ScriptBlock $ImportTestToolkitToBcContainer -ArgumentList $Parameters
        $testToolkitInstalled = $true
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nImporting Test Toolkit took $([int]$_.TotalSeconds) seconds" }

if ($installTestApps) {
Write-Host -ForegroundColor Yellow @'

  _____           _        _ _ _               _______       _                              
 |_   _|         | |      | | (_)             |__   __|     | |       /\                    
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _     | | ___ ___| |_     /  \   _ __  _ __  ___ 
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` |    | |/ _ \ __| __|   / /\ \ | '_ \| '_ \/ __|
  _| |_| | | \__ \ |_ (_| | | | | | | | (_| |    | |  __\__ \ |_   / ____ \| |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |    |_|\___|___/\__| /_/    \_\ .__/| .__/|___/
                                        __/ |                              | |   | |        
                                       |___/                               |_|   |_|        

'@
Measure-Command {

    if ($testCountry) {
        Write-Host -ForegroundColor Yellow "Installing test apps for additional country $testCountry"
    }

    $installTestApps | ForEach-Object{
        $Parameters = @{
            "containerName" = $containerName
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $_
            "skipVerification" = $true
            "sync" = $true
            "install" = $true
        }
        if ($bcAuthContext) {
            $Parameters += @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
            }
        }
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling testapps took $([int]$_.TotalSeconds) seconds" }
}

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

    $Parameters = @{ }
    $CopParameters = @{ }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
        }
    }

    if ($app) {
        $CopParameters += @{ 
            "EnableCodeCop" = $enableCodeCop
            "EnableAppSourceCop" = $enableAppSourceCop
            "EnableUICop" = $enableUICop
            "EnablePerTenantExtensionCop" = $enablePerTenantExtensionCop
            "failOn" = $failOn
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
                        "path" = Get-BcContainerPath -containerName $containerName -path $ruleSetFile
                    })
                }
                $appSourceRulesetFile = Join-Path $folder "appsource.default.ruleset.json"
                Download-File -sourceUrl "https://bcartifacts.azureedge.net/rulesets/appsource.default.ruleset.json" -destinationFile $appSourceRulesetFile
                $ruleset.includedRuleSets += @(@{ 
                    "action" = "Default"
                    "path" = Get-BcContainerPath -containerName $containerName -path $appSourceRulesetFile
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
        if ($testApp -and ($enablePerTenantExtensionCop -or $enableAppSourceCop)) {
            Write-Host -ForegroundColor Yellow "WARNING: A Test App cannot be published to production tenants online"
        }
    }

    $appJsonFile = Join-Path $folder "app.json"
    $appJsonChanges = $false
    $appJson = Get-Content $appJsonFile | ConvertFrom-Json
    if ($appBuild -or $appRevision) {
        $appJsonVersion = [System.Version]$appJson.Version
        $version = [System.Version]::new($appJsonVersion.Major, $appJsonVersion.Minor, $appBuild, $appRevision)
        Write-Host "Using Version $version"
        $appJson.version = "$version"
        $appJsonChanges = $true
    }

    if ($app -and $applicationInsightsKey) {
        if ($appJson.psobject.Properties.name -eq "applicationInsightskey") {
            $appJson.applicationInsightsKey = $applicationInsightsKey
        }
        else {
            Add-Member -InputObject $appJson -MemberType NoteProperty -Name "applicationInsightsKey" -Value $applicationInsightsKey
        }
        $appJsonChanges = $true
    }

    if ($appJsonChanges) {
        $appJson | ConvertTo-Json -Depth 99 | Set-Content $appJsonFile
    }

    if ($useDevEndpoint) {
        $appPackagesFolder = Join-Path $folder ".alPackages"
        $appOutputFolder = $folder
    }
    else {
        $appPackagesFolder = $packagesFolder
        $appOutputFolder = $outputFolder
        $Parameters += @{ "CopyAppToSymbolsFolder" = $true }
    }

    $Parameters += @{
        "containerName" = $containerName
        "tenant" = $tenant
        "credential" = $credential
        "appProjectFolder" = $folder
        "appOutputFolder" = $appOutputFolder
        "appSymbolsFolder" = $appPackagesFolder
        "AzureDevOps" = $azureDevOps
        "CopySymbolsFromContainer" = $CopySymbolsFromContainer
        "preProcessorSymbols" = $preProcessorSymbols
    }
    if ($enableAppSourceCop -and $app) {
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
                    $tmpFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
                    try {
                        Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson
                        $xappJsonFile = Join-Path $tmpFolder "app.json"
                        $xappJson = Get-Content $xappJsonFile | ConvertFrom-Json
                        Write-Host "$($xappJson.Publisher)_$($xappJson.Name) = $($xappJson.Version)"
                        $previousAppVersions += @{ "$($xappJson.Publisher)_$($xappJson.Name)" = $xappJson.Version }
                    }
                    catch {
                        throw "Cannot use previous app $([System.IO.Path]::GetFileName($appFile)), it might be a runtime package."
                    }
                    finally {
                        Remove-Item $tmpFolder -Recurse -Force
                    }
                }
            }
        }

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
        }
        else {
            if (Test-Path $appSourceCopJsonFile) {
                Remove-Item $appSourceCopJsonFile -force
            }
        }
    }

    try {
        $appFile = Invoke-Command -ScriptBlock $CompileAppInBcContainer -ArgumentList ($Parameters+$CopParameters)
    }
    catch {
        if ($escapeFromCops) {
            Write-Host "Retrying without Cops"
            $appFile = Invoke-Command -ScriptBlock $CompileAppInBcContainer -ArgumentList $Parameters
        }
        else {
            throw $_
        }
    }

    if ($useDevEndpoint) {

        $Parameters = @{
            "containerName" = $containerName
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
            }
        }

        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters

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
                    "authentication" =  'UserPassword'
                }
            }
            UpdateLaunchJson -launchJsonFile $launchJsonFile -launchSettings $launchSettings
        }
    }

    if ($testApp) {
        $testApps += $appFile
    }
    if ($app) {
        $apps += $appFile
        $appsFolder += @{ "$appFile" = $folder }
    }
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCompiling apps$measureText took $([int]$_.TotalSeconds) seconds" }

if ($signApps -and !$useDevEndpoint) {
Write-Host -ForegroundColor Yellow @'

   _____ _             _                                        
  / ____(_)           (_)                 /\                    
 | (___  _  __ _ _ __  _ _ __   __ _     /  \   _ __  _ __  ___ 
  \___ \| |/ _` | '_ \| | '_ \ / _` |   / /\ \ | '_ \| '_ \/ __|
  ____) | | (_| | | | | | | | | (_| |  / ____ \| |_) | |_) \__ \
 |_____/|_|\__, |_| |_|_|_| |_|\__, | /_/    \_\ .__/| .__/|___/
            __/ |               __/ |          | |   | |        
           |___/               |___/           |_|   |_|        

'@
Measure-Command {
$apps | ForEach-Object {

    $Parameters = @{
        "containerName" = $containerName
        "appFile" = $_
        "pfxFile" = $codeSignCertPfxFile
        "pfxPassword" = $codeSignCertPfxPassword
    }

    Invoke-Command -ScriptBlock $SignBcContainerApp -ArgumentList $Parameters

}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nSigning apps took $([int]$_.TotalSeconds) seconds" }
}
}

if (!$useDevEndpoint) {

if ($previousApps) {
Write-Host -ForegroundColor Yellow @'

  _____           _        _ _ _               _____                _                                            
 |_   _|         | |      | | (_)             |  __ \              (_)                     /\                    
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _  | |__) | __ _____   ___  ___  _   _ ___     /  \   _ __  _ __  ___ 
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | |  ___/ '__/ _ \ \ / / |/ _ \| | | / __|   / /\ \ | '_ \| '_ \/ __|
  _| |_| | | \__ \ |_ (_| | | | | | | | (_| | | |   | | |  __/\ V /| | (_) | |_| \__ \  / ____ \| |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, | |_|   |_|  \___| \_/ |_|\___/ \__,_|___/ /_/    \_\ .__/| .__/|___/
                                        __/ |                                                   | |   | |        
                                       |___/                                                    |_|   |_|        

'@
Measure-Command {
    if ($testCountry) {
        Write-Host -ForegroundColor Yellow "Installing previous apps for additional country $testCountry"
    }
    if ($previousApps) {
        $previousApps | ForEach-Object{
            $Parameters = @{
                "containerName" = $containerName
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
                }
            }
            Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
        }
        if ($bcAuthContext) {
            Write-Host "Wait for online environment to process apps"
            Start-Sleep -Seconds 30
        }
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
}

Write-Host -ForegroundColor Yellow @'

  _____       _     _ _     _     _                                        
 |  __ \     | |   | (_)   | |   (_)                 /\                    
 | |__) |   _| |__ | |_ ___| |__  _ _ __   __ _     /  \   _ __  _ __  ___ 
 |  ___/ | | | '_ \| | / __| '_ \| | '_ \ / _` |   / /\ \ | '_ \| '_ \/ __|
 | |   | |_| | |_) | | \__ \ | | | | | | | (_| |  / ____ \| |_) | |_) \__ \
 |_|    \__,_|_.__/|_|_|___/_| |_|_|_| |_|\__, | /_/    \_\ .__/| .__/|___/
                                           __/ |          | |   | |        
                                          |___/           |_|   |_|        

'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Publishing apps for additional country $testCountry"
}

$installedApps = @()
if (!($bcAuthContext)) {
    $installedApps = Invoke-Command -ScriptBlock $GetBcContainerAppInfo -ArgumentList $Parameters
}

$apps | ForEach-Object {
   
    $folder = $appsFolder[$_]
    $appJsonFile = Join-Path $folder "app.json"
    $appJson = Get-Content $appJsonFile | ConvertFrom-Json

    $installedApp = $false
    if ($installedApps | Where-Object { $_.Name -eq $appJson.Name -and $_.Publisher -eq $appJson.Publisher -and $_.AppId -eq $appJson.Id }) {
        $installedApp = $true
    }

    $Parameters = @{
        "containerName" = $containerName
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
        }
    }

    Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters

}

$testApps | ForEach-Object {
   
    $Parameters = @{
        "containerName" = $containerName
        "tenant" = $tenant
        "credential" = $credential
        "appFile" = $_
        "skipVerification" = $true
        "sync" = $true
        "install" = $true
    }

    if ($bcAuthContext) {
        $Parameters += @{
            "bcAuthContext" = $bcAuthContext
            "environment" = $environment
        }
    }

    Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters

}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPublishing apps took $([int]$_.TotalSeconds) seconds" }
}

if (!$doNotRunTests) {
if ($ImportTestDataInBcContainer) {
Write-Host -ForegroundColor Yellow @'
  _____                            _   _               _______       _     _____        _        
 |_   _|                          | | (_)             |__   __|     | |   |  __ \      | |       
   | |  _ __ ___  _ __   ___  _ __| |_ _ _ __   __ _     | | ___ ___| |_  | |  | | __ _| |_ __ _ 
   | | | '_ ` _ \| '_ \ / _ \| '__| __| | '_ \ / _` |    | |/ _ \ __| __| | |  | |/ _` | __/ _` |
  _| |_| | | | | | |_) | (_) | |  | |_| | | | | (_| |    | |  __\__ \ |_  | |__| | (_| | |_ (_| |
 |_____|_| |_| |_| .__/ \___/|_|   \__|_|_| |_|\__, |    |_|\___|___/\__| |_____/ \__,_|\__\__,_|
                 | |                            __/ |                                            
                 |_|                           |___/                                             
'@
if (!$enableTaskScheduler) {
    Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
        Write-Host "Enabling Task Scheduler to load configuration packages"
        Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "EnableTaskScheduler" -KeyValue "True" -WarningAction SilentlyContinue
        Set-NAVServerInstance -ServerInstance $ServerInstance -Restart
        while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
            Start-Sleep -Seconds 1
        }
    }
}

$Parameters = @{
    "containerName" = $containerName
    "tenant" = $tenant
    "credential" = $credential
}
Invoke-Command -ScriptBlock $ImportTestDataInBcContainer -ArgumentList $Parameters

if (!$enableTaskScheduler) {
    Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
        Write-Host "Disabling Task Scheduler again"
        Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "EnableTaskScheduler" -KeyValue "False" -WarningAction SilentlyContinue
        Set-NAVServerInstance -ServerInstance $ServerInstance -Restart
        while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
            Start-Sleep -Seconds 1
        }
    }
}
}
$allPassed = $true
$resultsFile = "$($testResultsFile.ToLowerInvariant().TrimEnd('.xml'))$testCountry.xml"
if ($testFolders) {
Write-Host -ForegroundColor Yellow @'

  _____                   _               _______       _       
 |  __ \                 (_)             |__   __|     | |      
 | |__) |   _ _ __  _ __  _ _ __   __ _     | | ___ ___| |_ ___ 
 |  _  / | | | '_ \| '_ \| | '_ \ / _` |    | |/ _ \ __| __/ __|
 | | \ \ |_| | | | | | | | | | | | (_| |    | |  __\__ \ |_\__ \
 |_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, |    |_|\___|___/\__|___/
                                   __/ |                        
                                  |___/                         

'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Running Tests for additional country $testCountry"
}

$testAppIds = @()
$installTestApps | ForEach-Object {
    $appFile = $_
    $tmpFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
    try {
        Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson
        $appJsonFile = Join-Path $tmpFolder "app.json"
        $appJson = Get-Content $appJsonFile | ConvertFrom-Json
        $testAppIds += @( $appJson.Id )
    }
    catch {
        Write-Host -ForegroundColor Red "Cannot run tests in test app $([System.IO.Path]::GetFileName($appFile)), it might be a runtime package."
    }
    finally {
        Remove-Item $tmpFolder -Recurse -Force
    }
}
$testFolders | ForEach-Object {
    $appJson = Get-Content -Path (Join-Path $_ "app.json") | ConvertFrom-Json
    $testAppIds += @( $appJson.Id )
}

$testAppIds | ForEach-Object {

    $Parameters = @{
        "containerName" = $containerName
        "tenant" = $tenant
        "credential" = $credential
        "extensionId" = $_
        "AzureDevOps" = "$(if($azureDevOps){'error'}else{'no'})"
        "detailed" = $true
        "returnTrueIfAllPassed" = $true
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
        }
    }

    if (!(Invoke-Command -ScriptBlock $RunTestsInBcContainer -ArgumentList $Parameters)) {
        $allPassed = $false
    }

}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRunning tests took $([int]$_.TotalSeconds) seconds" }
}
if ($buildArtifactFolder -and (Test-Path $resultsFile)) {
    Copy-Item -Path $resultsFile -Destination $buildArtifactFolder -Force
} 
if (($gitLab -or $gitHubActions) -and !$allPassed) {
    throw "There are test failures!"
}
}
}

if ($buildArtifactFolder) {
Write-Host -ForegroundColor Yellow @'
   _____                    _          ____        _ _     _                 _   _  __           _       
  / ____|                  | |        |  _ \      (_) |   | |     /\        | | (_)/ _|         | |      
 | |     ___  _ __  _   _  | |_ ___   | |_) |_   _ _| | __| |    /  \   _ __| |_ _| |_ __ _  ___| |_ ___ 
 | |    / _ \| '_ \| | | | | __/ _ \  |  _ <| | | | | |/ _` |   / /\ \ | '__| __| |  _/ _` |/ __| __/ __|
 | |____ (_) | |_) | |_| | | |_ (_) | | |_) | |_| | | | (_| |  / ____ \| |  | |_| | || (_| | (__| |_\__ \
  \_____\___/| .__/ \__, |  \__\___/  |____/ \__,_|_|_|\__,_| /_/    \_\_|   \__|_|_| \__,_|\___|\__|___/
             | |     __/ |                                                                               
             |_|    |___/                                                                                
'@

Measure-Command {

$destFolder = Join-Path $buildArtifactFolder "Apps"
if (!(Test-Path $destFolder -PathType Container)) {
    New-Item $destFolder -ItemType Directory | Out-Null
}
$apps | ForEach-Object {
    Copy-Item -Path $_ -Destination $destFolder -Force
}
$destFolder = Join-Path $buildArtifactFolder "TestApps"
if (!(Test-Path $destFolder -PathType Container)) {
    New-Item $destFolder -ItemType Directory | Out-Null
}
$testApps | ForEach-Object {
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
        $appJson = Get-Content -Path (Join-Path $folder "app.json") | ConvertFrom-Json
        Write-Host "Getting Runtime Package for $([System.IO.Path]::GetFileName($appFile))"

        $Parameters = @{
            "containerName" = $containerName
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
                "containerName" = $containerName
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

}

} catch {
    $error = $_
}
finally {
    $progressPreference = $prevProgressPreference
}

if (!$keepContainer) {
Write-Host -ForegroundColor Yellow @'

  _____                           _                _____            _        _                 
 |  __ \                         (_)              / ____|          | |      (_)                
 | |__) |___ _ __ ___   _____   ___ _ __   __ _  | |     ___  _ __ | |_ __ _ _ _ __   ___ _ __ 
 |  _  // _ \ '_ ` _ \ / _ \ \ / / | '_ \ / _` | | |    / _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | | \ \  __/ | | | | | (_) \ V /| | | | | (_| | | |____ (_) | | | | |_ (_| | | | | |  __/ |   
 |_|  \_\___|_| |_| |_|\___/ \_/ |_|_| |_|\__, |  \_____\___/|_| |_|\__\__,_|_|_| |_|\___|_|   
                                           __/ |                                               
                                          |___/                                                

'@
Measure-Command {

    $Parameters = @{
        "containerName" = $containerName
    }
    Invoke-Command -ScriptBlock $RemoveBcContainer -ArgumentList $Parameters
   
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRemoving container took $([int]$_.TotalSeconds) seconds" }

}

if ($error) {
    throw $error
}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nAL Pipeline finished in $([int]$_.TotalSeconds) seconds" }

}
Export-ModuleMember -Function Run-AlPipeline

