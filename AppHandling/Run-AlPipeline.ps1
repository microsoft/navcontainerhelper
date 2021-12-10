<# 
 .Synopsis
  Run AL Pipeline
 .Description
  Run AL Pipeline
 .Parameter pipelineName
  The name of the pipeline or project.
 .Parameter baseFolder
  The baseFolder serves as the base Folder for all other parameters including a path (appFolders, testFolders, testResultFile, outputFolder, packagesFolder and buildArtifactsFodler). This folder will be shared with the container as c:\sources
 .Parameter sharedFolder
  If a folder on the host computer is specified in the sharedFolder parameter, it will be shared with the container as c:\shared
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
 .Parameter previousApps
  Array or comma separated list of previous version of apps
 .Parameter appFolders
  Array or comma separated list of folders with apps to be compiled, signed and published
 .Parameter testFolders
  Array or comma separated list of folders with test apps to be compiled, published and run
 .Parameter additionalCountries
  Array or comma separated list of countries to test
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
 .Parameter testResultsFile
  Filename in which you want the test results to be written. Default is TestResults.xml, meaning that test results will be written to this filename in the base folder. This parameter is ignored if doNotRunTests is included.
 .Parameter bcptTestResultsFile
  Filename in which you want the bcpt test results to be written. Default is TestResults.xml, meaning that test results will be written to this filename in the base folder. This parameter is ignored if doNotRunTests is included.
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
 .Parameter doNotBuildTests
  Include this switch to indicate that you do not want to build nor tests.
 .Parameter doNotRunTests
  Include this switch to indicate that you do not want to execute tests. Test Apps will still be published and installed, test execution can later be performed from the UI.
 .Parameter doNotRunBcptTests
  Include this switch to indicate that you do not want to execute bcpt tests. Test Apps will still be published and installed, test execution can later be performed from the UI.
 .Parameter doNotPerformUpgrade
  Include this switch to indicate that you do not want to perform the upgrade. This means that the previousApps are never actually published to the container.
 .Parameter uninstallRemovedApps
  Include this switch to indicate that you want to uninstall apps, which are included in previousApps, but not included (upgraded) in apps, i.e. removed apps
 .Parameter reUseContainer
  Including the reUseContainer switch causes pipeline to reuse the container with the given name if it exists
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
 .Parameter customCodeCops
  Use custom AL Cops into the container and include them, in addidtion to the default cops, during compilation.
 .Parameter useDefaultAppSourceRuleSet
  Apply the default ruleset for passing AppSource validation
 .Parameter rulesetFile
  Filename of the custom ruleset file
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
 .Parameter RunTestsInBcContainer
  Override function parameter for Run-TestsInBcContainer
 .Parameter RunBCPTTestsInBcContainer
  Override function parameter for Run-BCPTTestsInBcContainer
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
    [string] $sharedFolder = "",
    [string] $licenseFile,
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
    $previousApps = @(),
    $appFolders = @("app", "application"),
    $testFolders = @("test", "testapp"),
    $bcptTestFolders = @("bcpttest", "bcpttestapp"),
    $additionalCountries = @(),
    [string] $appVersion = "",
    [int] $appBuild = 0,
    [int] $appRevision = 0,
    [string] $applicationInsightsKey,
    [string] $applicationInsightsConnectionString,
    [string] $testResultsFile = "TestResults.xml",
    [string] $bcptTestResultsFile = "bcptTestResults.json",
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
    [switch] $doNotBuildTests,
    [switch] $doNotRunTests,
    [switch] $doNotRunBcptTests,
    [switch] $doNotPerformUpgrade,
    [switch] $uninstallRemovedApps,
    [switch] $reUseContainer,
    [switch] $keepContainer,
    [string] $updateLaunchJson = "",
    [string] $vsixFile = "",
    [switch] $enableCodeCop,
    [switch] $enableAppSourceCop,
    [switch] $enableUICop,
    [switch] $enablePerTenantExtensionCop,
    $customCodeCops = @(),
    [switch] $useDefaultAppSourceRuleSet,
    [string] $rulesetFile = "",
    [string[]] $preProcessorSymbols = @(),
    [switch] $generatecrossreferences,
    [switch] $escapeFromCops,
    [Hashtable] $bcAuthContext,
    [string] $environment,
    $AppSourceCopMandatoryAffixes = @(),
    $AppSourceCopSupportedCountries = @(),
    [scriptblock] $DockerPull,
    [scriptblock] $NewBcContainer,
    [scriptblock] $SetBcContainerKeyVaultAadAppAndCertificate,
    [scriptblock] $ImportTestToolkitToBcContainer,
    [scriptblock] $CompileAppInBcContainer,
    [scriptblock] $GetBcContainerAppInfo,
    [scriptblock] $PublishBcContainerApp,
    [scriptblock] $UnPublishBcContainerApp,
    [scriptblock] $InstallBcAppFromAppSource,
    [scriptblock] $SignBcContainerApp,
    [scriptblock] $ImportTestDataInBcContainer,
    [scriptblock] $RunTestsInBcContainer,
    [scriptblock] $RunBCPTTestsInBcContainer,
    [scriptblock] $GetBcContainerAppRuntimePackage,
    [scriptblock] $RemoveBcContainer
)

function CheckRelativePath([string] $baseFolder, [string] $sharedFolder, $path, $name) {
    if ($path) {
        if (!$path.contains(':')) {
            if (Test-Path -path (Join-Path $baseFolder $path)) {
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

Function UpdateLaunchJson {
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

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

$warningsToShow = @()

if (!$baseFolder -or !(Test-Path $baseFolder -PathType Container)) {
    throw "baseFolder must be an existing folder"
}
if ($sharedFolder -and !(Test-Path $sharedFolder -PathType Container)) {
    throw "If sharedFolder is specified, it must be an existing folder"
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
if ($additionalCountries            -is [String]) { $additionalCountries = @($additionalCountries.Split(',').Trim() | Where-Object { $_ }) }
if ($AppSourceCopMandatoryAffixes   -is [String]) { $AppSourceCopMandatoryAffixes = @($AppSourceCopMandatoryAffixes.Split(',').Trim() | Where-Object { $_ }) }
if ($AppSourceCopSupportedCountries -is [String]) { $AppSourceCopSupportedCountries = @($AppSourceCopSupportedCountries.Split(',').Trim() | Where-Object { $_ }) }
if ($customCodeCops                 -is [String]) { $customCodeCops = @($customCodeCops.Split(',').Trim() | Where-Object { $_ }) }

$appFolders  = @($appFolders  | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "appFolders" } | Where-Object { Test-Path $_ } )
$testFolders = @($testFolders | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "testFolders" } | Where-Object { Test-Path $_ } )
$bcptTestFolders = @($bcptTestFolders | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "bcptTestFolders" } | Where-Object { Test-Path $_ } )
$customCodeCops = @($customCodeCops | ForEach-Object { CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $_ -name "customCodeCops" } | Where-Object { Test-Path $_ } )
$testResultsFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $testResultsFile -name "testResultsFile"
$bcptTestResultsFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $bcptTestResultsFile -name "bcptTestResultsFile"
$rulesetFile = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $rulesetFile -name "rulesetFile"
if (Test-Path $testResultsFile) {
    Remove-Item -Path $testResultsFile -Force
}
if (Test-Path $bcptTestResultsFile) {
    Remove-Item -Path $bcptTestResultsFile -Force
}

if ($bcptTestFolders) { $bcptTestFolders | ForEach-Object {
    if (-not (Test-Path (Join-Path $_ "bcptSuite.json"))) {
        throw "no bcptsuite.json found in bcpt test folder $_"        
    }
} }

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
    $packagesFolder = CheckRelativePath -baseFolder $baseFolder -sharedFolder $sharedFolder -path $packagesFolder -name "packagesFolder"
    if (Test-Path $packagesFolder) {
        Remove-Item $packagesFolder -Recurse -Force
    }

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

if ($gitHubActions) { Write-Host "::group::Parameters" }
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
Write-Host -NoNewLine -ForegroundColor Yellow "ReUseContainer              "; Write-Host $reUseContainer
Write-Host -NoNewLine -ForegroundColor Yellow "KeepContainer               "; Write-Host $keepContainer
Write-Host -NoNewLine -ForegroundColor Yellow "Auth                        "; Write-Host $auth
Write-Host -NoNewLine -ForegroundColor Yellow "Credential                  ";
if ($credential) {
    Write-Host "Specified"
}
else {
    $password = GetRandomPassword
    Write-Host "admin/$password"
    $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
Write-Host -NoNewLine -ForegroundColor Yellow "CompanyName                 "; Write-Host $companyName
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
Write-Host -NoNewLine -ForegroundColor Yellow "doNotPerformUpgrade         "; Write-Host $doNotPerformUpgrade
Write-Host -NoNewLine -ForegroundColor Yellow "uninstallRemovedApps        "; Write-Host $uninstallRemovedApps
Write-Host -NoNewLine -ForegroundColor Yellow "escapeFromCops              "; Write-Host $escapeFromCops
Write-Host -NoNewLine -ForegroundColor Yellow "doNotBuildTests             "; Write-Host $doNotBuildTests
Write-Host -NoNewLine -ForegroundColor Yellow "doNotRunTests               "; Write-Host $doNotRunTests
Write-Host -NoNewLine -ForegroundColor Yellow "doNotRunBcptTests           "; Write-Host $doNotRunBcptTests
Write-Host -NoNewLine -ForegroundColor Yellow "useDefaultAppSourceRuleSet  "; Write-Host $useDefaultAppSourceRuleSet
Write-Host -NoNewLine -ForegroundColor Yellow "rulesetFile                 "; Write-Host $rulesetFile
Write-Host -NoNewLine -ForegroundColor Yellow "azureDevOps                 "; Write-Host $azureDevOps
Write-Host -NoNewLine -ForegroundColor Yellow "gitLab                      "; Write-Host $gitLab
Write-Host -NoNewLine -ForegroundColor Yellow "gitHubActions               "; Write-Host $gitHubActions
Write-Host -NoNewLine -ForegroundColor Yellow "License file                "; if ($licenseFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertPfxFile         "; if ($codeSignCertPfxFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertPfxPassword     "; if ($codeSignCertPfxPassword) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertIsSelfSigned    "; Write-Host $codeSignCertIsSelfSigned.ToString()
Write-Host -NoNewLine -ForegroundColor Yellow "KeyVaultCertPfxFile         "; if ($keyVaultCertPfxFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "KeyVaultCertPfxPassword     "; if ($keyVaultCertPfxPassword) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "KeyVaultClientId            "; Write-Host $keyVaultClientId
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFile             "; Write-Host $testResultsFile
Write-Host -NoNewLine -ForegroundColor Yellow "BcptTestResultsFile         "; Write-Host $bcptTestResultsFile
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFormat           "; Write-Host $testResultsFormat
Write-Host -NoNewLine -ForegroundColor Yellow "AdditionalCountries         "; Write-Host ([string]::Join(',',$additionalCountries))
Write-Host -NoNewLine -ForegroundColor Yellow "PackagesFolder              "; Write-Host $packagesFolder
Write-Host -NoNewLine -ForegroundColor Yellow "OutputFolder                "; Write-Host $outputFolder
Write-Host -NoNewLine -ForegroundColor Yellow "BuildArtifactFolder         "; Write-Host $buildArtifactFolder
Write-Host -NoNewLine -ForegroundColor Yellow "CreateRuntimePackages       "; Write-Host $createRuntimePackages
Write-Host -NoNewLine -ForegroundColor Yellow "AppVersion                  "; Write-Host $appVersion
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
Write-Host -ForegroundColor Yellow "BCPT Test application folders"
if ($bcptTestFolders) { $bcptTestFolders | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Custom CodeCops"
if ($customCodeCops) { $customCodeCops | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }

if ($doNotBuildTests) {
    $testFolders = @()
    $bcptTestFolders = @()
    $installTestRunner = $false
    $installTestFramework = $false
    $installTestLibraries = $false
    $installPerformanceToolkit = $false
    $doNotRunTests = $true
    $doNotRunBcptTests = $true
}

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
if ($RunTestsInBcContainer) {
    Write-Host -ForegroundColor Yellow "RunTestsInBcContainer override"; Write-Host $RunTestsInBcContainer.ToString()
}
else {
    $RunTestsInBcContainer = { Param([Hashtable]$parameters) Run-TestsInBcContainer @parameters }
}
if ($RunBCPTTestsInBcContainer) {
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
if ($gitHubActions) { Write-Host "::endgroup::" }

$signApps = ($codeSignCertPfxFile -ne "")

Measure-Command {

if (!$reUseContainer -and $artifactUrl) {
if ($gitHubActions) { Write-Host "::group::Pulling Generic Image" }
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

if (!$useGenericImage) {
    $useGenericImage = Get-BestGenericImageName -filesOnly:$filesOnly
}

Write-Host "Pulling $useGenericImage"

Invoke-Command -ScriptBlock $DockerPull -ArgumentList $useGenericImage
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPulling generic image took $([int]$_.TotalSeconds) seconds" }
if ($gitHubActions) { Write-Host "::endgroup::" }
}

$error = $null
$prevProgressPreference = $progressPreference
$progressPreference = 'SilentlyContinue'

try {

@("")+$additionalCountries | % {
$testCountry = $_.Trim()

if ($gitHubActions) { Write-Host "::group::Creating Container" }
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

    if ($useExistingContainer) {
        Write-Host "Reusing existing container"
    }
    else {
        if ($bcAuthContext) {
            $Parameters += @{
                "FilesOnly" = $filesOnly
            }
        }

        if ($imageName)   { $Parameters += @{ "imageName"   = $imageName } }
        if ($memoryLimit) { $Parameters += @{ "memoryLimit" = $memoryLimit } }

        $Parameters += @{
            "accept_eula" = $true
            "containerName" = $containerName
            "artifactUrl" = $artifactUrl
            "useGenericImage" = $useGenericImage
            "Credential" = $credential
            "auth" = $auth
            "vsixFile" = $vsixFile
            "updateHosts" = $true
            "licenseFile" = $licenseFile
            "EnableTaskScheduler" = $enableTaskScheduler
            "AssignPremiumPlan" = $assignPremiumPlan
            "additionalParameters" = @("--volume ""$($baseFolder):c:\sources""")
        }
        if ($sharedFolder) {
            $Parameters.additionalParameters += @("--volume ""$($sharedFolder):c:\shared""")
        }
        Invoke-Command -ScriptBlock $NewBcContainer -ArgumentList $Parameters

        if (-not $bcAuthContext) {
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
if ($gitHubActions) { Write-Host "::endgroup::" }

if ($installApps) {
if ($gitHubActions) { Write-Host "::group::Installing apps" }
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
        $appId = [Guid]::Empty
        if ([Guid]::TryParse($_, [ref] $appId)) {
            if (-not $bcAuthContext) {
                throw "InstallApps can only specify AppIds for AppSource Apps when running against a cloud instance"
            }
            $Parameters = @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
                "appId" = "$appId"
                "acceptIsvEula" = $true
                "installOrUpdateNeededDependencies" = $true
            }
            Invoke-Command -ScriptBlock $InstallBcAppFromAppSource -ArgumentList $Parameters
        }
        else {
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

    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
if ($gitHubActions) { Write-Host "::endgroup::" }
}

if ((($testCountry) -or ($installTestApps)) -and ($installTestRunner -or $installTestFramework -or $installTestLibraries -or $installPerformanceToolkit)) {
if ($gitHubActions) { Write-Host "::group::Importing Test Toolkit" }
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
if ($gitHubActions) { Write-Host "::endgroup::" }

if ($installTestApps) {
if ($gitHubActions) { Write-Host "::group::Installing Test Apps" }
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
        $appId = [Guid]::Empty
        if ([Guid]::TryParse($_, [ref] $appId)) {
            if (-not $bcAuthContext) {
                throw "InstallApps can only specify AppIds for AppSource Apps when running against a cloud instance"
            }
            $Parameters = @{
                "bcAuthContext" = $bcAuthContext
                "environment" = $environment
                "appId" = "$appId"
                "acceptIsvEula" = $true
                "installOrUpdateNeededDependencies" = $true
            }
            Invoke-Command -ScriptBlock $InstallBcAppFromAppSource -ArgumentList $Parameters
        }
        else {
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
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling testapps took $([int]$_.TotalSeconds) seconds" }
if ($gitHubActions) { Write-Host "::endgroup::" }
}
}

if (-not $testCountry) {
if ($appFolders -or $testFolders -or $bcptTestFolders) {
if ($gitHubActions) { Write-Host "::group::Compiling apps" }
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
$apps = @()
$testApps = @()
$bcptTestApps = @()
$testToolkitInstalled = $false
$sortedFolders = @(Sort-AppFoldersByDependencies -appFolders $appFolders -WarningAction SilentlyContinue) + 
                 @(Sort-AppFoldersByDependencies -appFolders $testFolders -WarningAction SilentlyContinue) +
                 @(Sort-AppFoldersByDependencies -appFolders $bcptTestFolders -WarningAction SilentlyContinue)
$sortedFolders | Select-Object -Unique | ForEach-Object {
    $folder = $_

    $bcptTestApp = $bcptTestFolders.Contains($folder)
    $testApp = $testFolders.Contains($folder)
    $app = $appFolders.Contains($folder)

    if ($testApp -and !$testToolkitInstalled -and ($installTestRunner -or $installTestFramework -or $installTestLibraries -or $installPerformanceToolkit)) {

if ($gitHubActions) { Write-Host "::endgroup::" }
if ($gitHubActions) { Write-Host "::group::Importing Test Toolkit" }
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
if ($gitHubActions) { Write-Host "::endgroup::" }
if ($gitHubActions) { Write-Host "::group::Installing Test Apps" }
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

if ($gitHubActions) { Write-Host "::endgroup::" }
if ($gitHubActions) { Write-Host "::group::Compiling test apps" }
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

        if ($customCodeCops.Count -gt 0) {
            $CopParameters += @{
                "CustomCodeCops" = $customCodeCops
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
    }
    if ($testApp -and ($enablePerTenantExtensionCop -or $enableAppSourceCop)) {
        Write-Host -ForegroundColor Yellow "WARNING: A Test App cannot be published to production tenants online"
    }

    $appJsonFile = Join-Path $folder "app.json"
    $appJsonChanges = $false
    $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
    if ($appVersion -or $appBuild -or $appRevision) {
        if ($appVersion) {
            $version = [System.Version]"$($appVersion).$($appBuild).$($appRevision)"
        }
        else {
            $appJsonVersion = [System.Version]$appJson.Version
            $version = [System.Version]::new($appJsonVersion.Major, $appJsonVersion.Minor, $appBuild, $appRevision)
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
        "GitHubActions" = $gitHubActions
        "CopySymbolsFromContainer" = $CopySymbolsFromContainer
        "preProcessorSymbols" = $preProcessorSymbols
        "generatecrossreferences" = $generatecrossreferences
    }
    if ($app) {
        if (!$previousAppsCopied) {
            $previousAppsCopied = $true
            $AppList = @()
            $previousAppVersions = @{}
            if ($previousApps) {
                Write-Host "Copying previous apps to packages folder"
                $appList = CopyAppFilesToFolder -appFiles $previousApps -folder $appPackagesFolder
                $previousApps = Sort-AppFilesByDependencies -appFiles $appList -containerName $containerName
                $previousApps | ForEach-Object {
                    $appFile = $_

                    $appInfo = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                        param($appFile)

                        Get-NavAppInfo -Path $appFile
                    } -argumentList (Get-BcContainerPath -containerName $containerName -path $appFile)

                    Write-Host "$($appInfo.Publisher)_$($appInfo.Name) = $($appInfo.Version.ToString())"
                    $previousAppVersions += @{ "$($appInfo.Publisher)_$($appInfo.Name)" = $appInfo.Version.ToString() }
                    $previousAppInfos += @(@{
                        "AppId" = $appInfo.AppId.ToLowerInvariant()
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
if ($gitHubActions) { Write-Host "::endgroup::" }

if ($signApps -and !$useDevEndpoint) {
if ($gitHubActions) { Write-Host "::group::Signing Apps" }
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
        "importCertificate" = $codeSignCertIsSelfSigned
    }

    Invoke-Command -ScriptBlock $SignBcContainerApp -ArgumentList $Parameters

}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nSigning apps took $([int]$_.TotalSeconds) seconds" }
if ($gitHubActions) { Write-Host "::endgroup::" }
}
}

$previousAppsInstalled = @()
if (!$useDevEndpoint) {

if ((!$doNotPerformUpgrade) -and ($previousApps)) {
if ($gitHubActions) { Write-Host "::group::Installing Previous Apps" }
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
if ($gitHubActions) { Write-Host "::endgroup::" }
}

if ($apps+$testApps+$bcptTestApps) {
if ($gitHubActions) { Write-Host "::group::Publishing Apps" }
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

$upgradedApps = @()
$apps | ForEach-Object {
   
    $folder = $appsFolder[$_]
    $appJsonFile = Join-Path $folder "app.json"
    $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
    $upgradedApps += @($appJson.Id.ToLowerInvariant())

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

if ($uninstallRemovedApps -and !$doNotPerformUpgrade) {
    [array]::Reverse($previousAppInfos)
    $previousAppInfos | ForEach-Object {
        if (!$upgradedApps.Contains($_.AppId)) {
            Write-Host "Uninstalling $($_.Name) version $($_.Version) from $($_.Publisher)"
            $Parameters = @{
                "containerName" = $containerName
                "tenant" = $tenant
                "name" = $_.Name
                "publisher" = $_.Publisher
                "version" = $_.Version
                "uninstall" = $true
            }
        
            Invoke-Command -ScriptBlock $UnPublishBcContainerApp -ArgumentList $Parameters
        }
    }
}

$testApps+$bcptTestApps | ForEach-Object {
   
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
if ($gitHubActions) { Write-Host "::endgroup::" }
}
}

if (!($doNotRunTests -and $doNotRunBcptTests)) {
if ($ImportTestDataInBcContainer) {
if ($gitHubActions) { Write-Host "::group::Importing Test Data" }
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
if ($gitHubActions) { Write-Host "::endgroup::" }
}
$allPassed = $true
$resultsFile = Join-Path ([System.IO.Path]::GetDirectoryName($testResultsFile)) "$([System.IO.Path]::GetFileNameWithoutExtension($testResultsFile))$testCountry.xml"
$bcptResultsFile = Join-Path ([System.IO.Path]::GetDirectoryName($bcptTestResultsFile)) "$([System.IO.Path]::GetFileNameWithoutExtension($bcptTestResultsFile))$testCountry.json"
if (!$doNotRunTests -and (($testFolders) -or ($installTestApps))) {
if ($gitHubActions) { Write-Host "::group::Running Tests" }
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

$testAppIds = @{}
$installTestApps | ForEach-Object {
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
        $tmpFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
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

$testAppIds.Keys | ForEach-Object {
    $disabledTests = @()
    $id = $_
    $folder = $testAppIds."$id"

    if ($folder) {
        Write-Host "Running tests for App $id in $folder"
    }
    else {
        Write-Host "Running tests for App $id"
    }
    if ($folder) {
        Get-ChildItem -Path $folder -Filter "disabledTests.json" -Recurse | ForEach-Object {
            $disabledTestsStr = Get-Content $_.FullName -Raw
            Write-Host "Disabled Tests:`n$disabledTestsStr"
            $disabledTests += @($disabledTestsStr | ConvertFrom-Json)
        }
    }
    $Parameters = @{
        "containerName" = $containerName
        "tenant" = $tenant
        "credential" = $credential
        "companyName" = $companyName
        "extensionId" = $id
        "disabledTests" = $disabledTests
        "AzureDevOps" = "$(if($azureDevOps){'error'}else{'no'})"
        "GitHubActions" = "$(if($githubActions){'error'}else{'no'})"
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
if ($buildArtifactFolder -and (Test-Path $resultsFile)) {
    Write-Host "Copying test results to output"
    Copy-Item -Path $resultsFile -Destination $buildArtifactFolder -Force
} 
if ($gitHubActions) { Write-Host "::endgroup::" }
}

if (!$doNotRunBcptTests -and $bcptTestFolders) {
if ($gitHubActions) { Write-Host "::group::Running BCPT Tests" }
Write-Host -ForegroundColor Yellow @'

  _____                   _                ____   _____ _____ _______   _______       _       
 |  __ \                 (_)              |  _ \ / ____|  __ \__   __| |__   __|     | |      
 | |__) |   _ _ __  _ __  _ _ __   __ _   | |_) | |    | |__) | | |       | | ___ ___| |_ ___ 
 |  _  / | | | '_ \| '_ \| | '_ \ / _` |  |  _ <| |    |  ___/  | |       | |/ _ \ __| __/ __|
 | | \ \ |_| | | | | | | | | | | | (_| |  | |_) | |____| |      | |       | |  __\__ \ |_\__ \
 |_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, |  |____/ \_____|_|      |_|       |_|\___|___/\__|___/
                                   __/ |                                                      
                                  |___/                                                       

'@
Measure-Command {
if ($testCountry) {
    Write-Host -ForegroundColor Yellow "Running BCPT Tests for additional country $testCountry"
}

$bcptTestFolders | ForEach-Object {
    $Parameters = @{
        "containerName" = $containerName
        "tenant" = $tenant
        "credential" = $credential
        "companyName" = $companyName
        "connectFromHost" = $true
        "BCPTsuite" = [System.IO.File]::ReadAllLines((Join-Path $_ "bcptSuite.json")) | ConvertFrom-Json
    }

    if ($bcAuthContext) {
        throw "BCPT Tests are not supported on cloud pipelines yet!"
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
if ($gitHubActions) { Write-Host "::endgroup::" }
}

if (($gitLab -or $gitHubActions) -and !$allPassed) {
    throw "There are test failures!"
}
}
}

if ($buildArtifactFolder) {
if ($gitHubActions) { Write-Host "::group::Copy to Build Artifacts" }
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
        $appJson = [System.IO.File]::ReadAllLines((Join-Path $folder "app.json")) | ConvertFrom-Json
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

Write-Host "Files in build artifacts folder:"
Get-ChildItem $buildArtifactFolder -Recurse | Where-Object {!$_.PSIsContainer} | ForEach-Object { Write-Host "$($_.FullName.Substring($buildArtifactFolder.Length+1)) ($($_.Length) bytes)" }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCopying to Build Artifacts took $([int]$_.TotalSeconds) seconds" }
if ($gitHubActions) { Write-Host "::endgroup::" }
}

} catch {
    $error = $_
}
finally {
    $progressPreference = $prevProgressPreference
}

if (!$keepContainer) {
if ($gitHubActions) { Write-Host "::group::Removing Container" }
if (!($error)) {
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
}
Measure-Command {

    $Parameters = @{
        "containerName" = $containerName
    }
    Invoke-Command -ScriptBlock $RemoveBcContainer -ArgumentList $Parameters
   
} | ForEach-Object { if (!($error)) { Write-Host -ForegroundColor Yellow "`nRemoving container took $([int]$_.TotalSeconds) seconds" } }
if ($gitHubActions) { Write-Host "::endgroup::" }
}

if ($warningsToShow) {
    ($warningsToShow -join "`n") | Write-Host -ForegroundColor Yellow
}

if ($error) {
    throw $error
}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nAL Pipeline finished in $([int]$_.TotalSeconds) seconds" }

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
