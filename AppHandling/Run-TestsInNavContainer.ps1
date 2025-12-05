<# 
 .Synopsis
  Run a test suite in a NAV/BC Container
 .Description
 .Parameter containerName
  Name of the container in which you want to run a test suite
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter companyName
  company to use
 .Parameter profile
  profile to use
 .Parameter credential
  Credentials of the SUPER user if using NavUserPassword authentication
 .Parameter sqlcredential
  SQL Credential if using an external sql server
 .Parameter accesstoken
  If your container is running AAD authentication, you need to specify an accesstoken for the user specified in credential
 .Parameter testSuite
  Name of test suite to run. Default is DEFAULT.
 .Parameter testGroup
  Only supported in 14.x containers or older. Name of test group to run. Wildcards (? and *) are supported. Default is *.
 .Parameter testCodeunit
  Name or ID of test codeunit to run. Wildcards (? and *) are supported. Default is *.
  This parameter will not populate the test suite with the specified codeunit. This is used as a filter on the tests that are already present
  (or otherwise loaded) in the suite.
  This is not to be confused with -testCodeunitRange.
 .Parameter testCodeunitRange
  A BC-compatible filter string to use for loading test codeunits (similar to -extensionId). This is not to be confused with -testCodeunit.
  If you set this parameter to '*', all test codeunits will be loaded.
  This might not work on all versions of BC and only works when using the command-line-testtool.
 .Parameter testFunction
  Name of test function to run. Wildcards (? and *) are supported. Default is *.
 .Parameter ExtensionId
  Specifying an extensionId causes the test tool to run all tests in the app with this app id.\
 .PARAMETER requiredTestIsolation
  Specify the required test isolation level. This is used to filter the tests that are run.
 .Parameter testType
  Specify the type of tests to run. This is used to filter the tests that are run.
 .Parameter appName
  The app name of then extension with id extensionId.
 .Parameter TestRunnerCodeunitId
  Specifying a TestRunnerCodeunitId causes the test tool to switch to this test runner.
 .Parameter XUnitResultFileName
  Filename where the function should place an XUnit compatible result file
 .Parameter AppendToXUnitResultFile
  Specify this switch if you want the function to append to the XUnit compatible result file instead of overwriting it
 .Parameter JUnitResultFileName
  Filename where the function should place an JUnit compatible result file
 .Parameter AppendToJUnitResultFile
  Specify this switch if you want the function to append to the JUnit compatible result file instead of overwriting it
 .Parameter ReRun
  Specify this switch if you want the function to replace an existing test run (of the same test codeunit) in the test result file instead of adding it
 .Parameter AzureDevOps
  Generate Azure DevOps Pipeline compatible output. This setting determines the severity of errors.
 .Parameter GitHubActions
  Generate GitHub Actions compatible output. This setting determines the severity of errors.
 .Parameter detailed
  Include this switch to output success/failure information for all tests.
 .Parameter InteractionTimeout
  Timespan allowed for a single interaction (Running a test codeunit is an interaction). Default is 24 hours.
 .Parameter ReturnTrueIfAllPassed
  Specify this switch if the function should return true/false on whether all tests passes. If not specified, the function returns nothing.
 .Parameter testPage
  ID of the test page to use. Default for 15.x containers is 130455. Default for 14.x containers and earlier is 130409.
 .Parameter culture
  Set the culture when running the tests. Default is en-US. Microsoft tests are written for en-US.
 .Parameter timezone
  Set the timezone when running the tests. Default is current timezone.
 .Parameter debugMode
  Include this switch to output debug information if running the tests fails.
 .Parameter usePublicWebBaseUrl
  Connect to the public Url and not to localhost
 .Parameter disabledTests
  DisabledTests is an array of disabled tests. Example: @( @{ "codeunitName" = "name"; "method" = "*" } )
  If you have the disabledTests in a file, you need to convert the file to Json: -disabledTests (Get-Content $filename | ConvertFrom-Json)
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the function will run tests on the online Business Central Environment specified
 .Parameter environment
  Environment to use for the running tests
 .Parameter restartContainerAndRetry
  Include this switch to restart container and retry the operation (everything) on non-recoverable errors.
  This is NOT test failures, but more things like out of memory, communication errors or that kind.
 .Parameter connectFromHost
  Run the Test Runner PS functions on the host connecting to the public Web BaseUrl to allow web debuggers like fiddler to trace connections
 .Example
  Run-TestsInBcContainer -containerName test -credential $credential
 .Example
  Run-TestsInBcContainer -containerName $containername -credential $credential -XUnitResultFileName "c:\ProgramData\BcContainerHelper\$containername.results.xml" -AzureDevOps "warning"
 .Example
  Run-TestsInBcContainer -containerName $containername -credential $credential -JUnitResultFileName "c:\ProgramData\BcContainerHelper\$containername.results.xml" -GitHubActions "warning"
#>
function Run-TestsInBcContainer {
    Param (
        [string] $containerName = '',
        [string] $compilerFolder = '',
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [string] $companyName = "",
        [Parameter(Mandatory=$false)]
        [string] $profile = "",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [Parameter(Mandatory=$false)]
        [PSCredential] $sqlCredential = $credential,
        [Parameter(Mandatory=$false)]
        [string] $accessToken = "",
        [Parameter(Mandatory=$false)]
        [string] $testSuite = "DEFAULT",
        [Parameter(Mandatory=$false)]
        [string] $testGroup = "*",
        [Parameter(Mandatory=$false)]
        [string] $testCodeunit = "*",
        [Parameter(Mandatory=$false)]
        [string] $testCodeunitRange = "",
        [Parameter(Mandatory=$false)]
        [string] $testFunction = "*",
        [string] $extensionId = "",
        [Parameter(Mandatory=$false)]
        [string] $requiredTestIsolation = "",
        [Parameter(Mandatory=$false)]
        [string] $testType = "",
        [string] $appName = "",
        [string] $testRunnerCodeunitId = "",
        [array]  $disabledTests = @(),
        [Parameter(Mandatory=$false)]
        [string] $XUnitResultFileName,
        [switch] $AppendToXUnitResultFile,
        [string] $JUnitResultFileName,
        [switch] $AppendToJUnitResultFile,
        [switch] $ReRun,
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no',
        [ValidateSet('no','error','warning')]
        [string] $GitHubActions = 'no',
        [switch] $detailed,
        [timespan] $interactionTimeout = [timespan]::FromHours(24),
        [switch] $returnTrueIfAllPassed,
        [Parameter(Mandatory=$false)]
        [int] $testPage,
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode = $bcContainerHelperConfig.debugMode,
        [switch] $restartContainerAndRetry,
        [switch] $usePublicWebBaseUrl,
        [string] $useUrl = "",
        [switch] $connectFromHost,
        [Hashtable] $bcAuthContext,
        [string] $environment,
        [switch] $renewClientContextBetweenTests = $bcContainerHelperConfig.renewClientContextBetweenTests
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if ($compilerFolder -and -not $containerName) {
        Write-Host "Using CompilerFolder without Container"
        $customConfig = $null
        $symbolsFolder = Join-Path $compilerFolder "symbols"
        $baseAppFile = GetSymbolFiles -path $symbolsFolder -baseName 'Microsoft_Base Application' | Select-Object -First 1
        $baseAppInfo = Get-AppJsonFromAppFile -appFile $baseAppFile.FullName

        $version = [Version]$baseAppInfo.version
        $PsTestToolFolder = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString())"
        New-Item $PsTestToolFolder -ItemType Directory | Out-Null
        $testDlls = Join-Path $compilerFolder "dlls/Test Assemblies/*.dll"
        Copy-Item $testDlls -Destination $PsTestToolFolder -Force
        Copy-Item -Path (Join-Path $PSScriptRoot "PsTestFunctions.ps1") -Destination $PsTestToolFolder -Force
        Copy-Item -Path (Join-Path $PSScriptRoot "ClientContext.ps1") -Destination $PsTestToolFolder -Force
        $connectFromHost = $true
    }
    else {
        if (-not $containerName) {
            $containerName = $bcContainerHelperConfig.defaultContainerName
        }
        Write-Host "Using Container"
        $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName
        $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
        $version = [System.Version]($navversion.split('-')[0])
        $PsTestToolFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\PsTestTool"
    }

    if ($bcAuthContext -and $environment) {
        if ($environment -like 'https://*') {
            $useUrl = $environment
            if ($bcAuthContext.ContainsKey('Username') -and $bcAuthContext.ContainsKey('Password')) {
                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $bcAuthContext.Username, $bcAuthContext.Password
                $clientServicesCredentialType = "NavUserPassword"
            }
            if ($bcAuthContext.ContainsKey('ClientServicesCredentialType')) {
                $clientServicesCredentialType = $bcAuthContext.ClientServicesCredentialType
            }
            $testPage = 130455
        }
        else {
            $response = Invoke-RestMethod -Method Get -Uri "$($bcContainerHelperConfig.baseUrl.TrimEnd('/'))/$($bcAuthContext.tenantID)/$environment/deployment/url"
            if($response.status -ne 'Ready') {
                throw "environment not ready, status is $($response.status)"
            }
            $useUrl = $response.data
            if ($testPage) {
                throw "You cannot specify testPage when running tests in an Online tenant"
            }
            $testPage = 130455
        }
        $uri = [Uri]::new($useUrl)
        $useUrl = $useUrl.Split('?')[0]
        $dict = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        if ($dict['tenant']) { $tenant = $dict['tenant'] }
        if ($dict['testpage']) { $testpage = [int]$dict['testpage'] }
    }
    else {
        $clientServicesCredentialType = $customConfig.ClientServicesCredentialType

        $useTraefik = $false
        $inspect = docker inspect $containerName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('traefik.enable').Count -gt 0) {
            if ($inspect.config.Labels.'traefik.enable' -eq "true") {
                $usePublicWebBaseUrl = ($useUrl -eq "")
                $useTraefik = $true
            }
        }
        if ($usePublicWebBaseUrl -and $useUrl -ne "") {
            throw "You cannot specify usePublicWebBaseUrl and useUrl at the same time"
        }

        if ($customConfig.PublicWebBaseUrl -eq "") {
            throw "Container $containerName needs to include the WebClient in order to run tests (PublicWebBaseUrl is blank)"
        }

        if ($useUrl -eq "") {
            if ([bool]($customConfig.PSobject.Properties.name -eq "EnableTaskScheduler")) {
                if ($customConfig.EnableTaskScheduler -eq "True") {
                    Write-Host -ForegroundColor Red "WARNING: TaskScheduler is running in the container, this can lead to test failures. Specify -EnableTaskScheduler:`$false to disable Task Scheduler."
                }
            }
        }
        if (!$testPage) {
            if ($version.Major -ge 15) {
                $testPage = 130455
            }
            else {
                $testPage = 130409
            }
        }

        if ($clientServicesCredentialType -eq "Windows" -and "$CompanyName" -eq "") {
            $myName = $myUserName.SubString($myUserName.IndexOf('\')+1)
            Get-BcContainerBcUser -containerName $containerName | Where-Object { $_.UserName.EndsWith("\$MyName", [System.StringComparison]::InvariantCultureIgnoreCase) -or $_.UserName -eq $myName } | % {
                $companyName = $_.Company
            }
        }
    
        Invoke-ScriptInBCContainer -containerName $containerName -scriptBlock { Param($timeoutStr)
            $webConfigFile = "C:\inetpub\wwwroot\$WebServerInstance\web.config"
            try {
                $webConfig = [xml](Get-Content $webConfigFile)
                $node = $webConfig.configuration.'system.webServer'.aspNetCore.Attributes.GetNamedItem('requestTimeout')
                if (!($node)) {
                    $node = $webConfig.configuration.'system.webServer'.aspNetCore.Attributes.Append($webConfig.CreateAttribute('requestTimeout'))
                }
                if ($node.Value -ne $timeoutStr) {
                    $node.Value = $timeoutStr
                    $webConfig.Save($webConfigFile)
                }
            }
            catch {
                Write-Host "WARNING: could not set requestTimeout in web.config"
            }
        } -argumentList $interactionTimeout.ToString()
    }

    if ($bcAuthContext -and ($environment -notlike 'https://*')) {
        if ($bcAuthContext.scopes -notlike "https://projectmadeira.com/*") {
            Write-Host -ForegroundColor Red "WARNING: AuthContext.Scopes is '$($bcAuthContext.Scopes)', should have been 'https://projectmaderia.com/'"
        }
        $bcAuthContext = Renew-BcAuthContext $bcAuthContext
        $accessToken = $bcAuthContext.accessToken
        $credential = New-Object pscredential -ArgumentList $bcAuthContext.upn, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)
    }

    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"
    $fobfile = Join-Path $PsTestToolFolder "PSTestToolPage.fob"

    if ($testPage -eq 130455) {
        if ($testgroup -ne "*" -and $testgroup -ne "") {
            Write-Host -ForegroundColor Red "WARNING: TestGroups are not supported in Business Central 15.x and later"
        }
    }

    If (!(Test-Path -Path $PsTestToolFolder -PathType Container)) {
        try {
            New-Item -Path $PsTestToolFolder -ItemType Directory | Out-Null
    
            Copy-Item -Path (Join-Path $PSScriptRoot "PsTestFunctions.ps1") -Destination $PsTestFunctionsPath -Force
            Copy-Item -Path (Join-Path $PSScriptRoot "ClientContext.ps1") -Destination $ClientContextPath -Force

            if ($version.Major -ge 15) {
                if ($testPage -eq 130409) {
                    Publish-BcContainerApp -containerName $containerName -appFile (Join-Path $PSScriptRoot "Microsoft_PSTestToolPage_15.0.0.0.app") -skipVerification -sync -install
                }
            }
            else {
                if ($version.Major -lt 11) {
                    Copy-Item -Path (Join-Path $PSScriptRoot "PSTestToolPage$($version.Major).fob") -Destination $fobfile -Force
                }
                else {
                    Copy-Item -Path (Join-Path $PSScriptRoot "PSTestToolPage.fob") -Destination $fobfile -Force
                }

                if ($clientServicesCredentialType -eq "Windows") {
                    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile
                } else {
                    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $sqlCredential
                }
            }
        } catch {
            Remove-Item -Path $PsTestToolFolder -Recurse -Force
            throw
        }
    }

    while ($true) {
        try
        {
            if ($connectFromHost) {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    throw "Using ConnectFromHost requires PowerShell 7"
                }
                $newtonSoftDllPath = Join-Path $PsTestToolFolder "Newtonsoft.Json.dll"
                $clientDllPath = Join-Path $PsTestToolFolder "Microsoft.Dynamics.Framework.UI.Client.dll"
                if ($containerName) {
                    if (!((Test-Path $newtonSoftDllPath) -and (Test-Path $clientDllPath))) {
                        Invoke-ScriptInBcContainer -containerName $containerName { Param([string] $myNewtonSoftDllPath, [string] $myClientDllPath)
                            if (!(Test-Path $myNewtonSoftDllPath)) {
                                $newtonSoftDllPath = "C:\Program Files\Microsoft Dynamics NAV\*\Service\Management\Newtonsoft.Json.dll"
                                if (!(Test-Path $newtonSoftDllPath)) {
                                    $newtonSoftDllPath = "C:\Program Files\Microsoft Dynamics NAV\*\Service\Newtonsoft.Json.dll"
                                }
                                $newtonSoftDllPath = (Get-Item $newtonSoftDllPath).FullName
                                Copy-Item -Path $newtonSoftDllPath -Destination $myNewtonSoftDllPath
                            }
                            $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
                            if (!(Test-Path $myClientDllPath)) {
                                Copy-Item -Path $clientDllPath -Destination $myClientDllPath
                                $antiSSRFdll = Join-Path ([System.IO.Path]::GetDirectoryName($clientDllPath)) 'Microsoft.Internal.AntiSSRF.dll'
                                if (Test-Path $antiSSRFdll) {
                                    Copy-Item -Path $antiSSRFdll -Destination ([System.IO.Path]::GetDirectoryName($myClientDllPath))
                                }
                            }
                        } -argumentList $newtonSoftDllPath, $clientDllPath
                    }
                }
    
                if ($useUrl) {
                    $publicWebBaseUrl = $useUrl.TrimEnd('/')
                }
                else {
                    $publicWebBaseUrl = $customConfig.PublicWebBaseUrl.TrimEnd('/')
                }
                $serviceUrl = "$publicWebBaseUrl/cs?tenant=$tenant"
    
                if ($accessToken) {
                    $clientServicesCredentialType = "AAD"
                    $credential = New-Object pscredential $credential.UserName, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)
                }
        
                if ($companyName) {
                    $serviceUrl += "&company=$([Uri]::EscapeDataString($companyName))"
                }

                if ($profile) {
                    $serviceUrl += "&profile=$([Uri]::EscapeDataString($profile))"
                }
    
                . $PsTestFunctionsPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath
        
                Write-Host "Connecting to $serviceUrl"
                $clientContext = $null
                try {
                    $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

                    $Param = @{}
                    if ($renewClientContextBetweenTests) {
                        $Param = @{ "renewClientContext" = { 
                                if ($renewClientContextBetweenTests) {
                                    Write-Host "Renewing Client Context"
                                    Remove-ClientContext -clientContext $clientContext
                                    $clientContext = $null
                                    $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode
                                    Write-Host "Client Context renewed"
                                }
                                $clientContext
                            }
                        }
                    }

                    $result = Run-Tests @Param -clientContext $clientContext `
                              -TestSuite $testSuite `
                              -TestGroup $testGroup `
                              -TestCodeunit $testCodeunit `
                              -TestCodeunitRange $testCodeunitRange `
                              -TestFunction $testFunction `
                              -ExtensionId $extensionId `
                              -RequiredTestIsolation $requiredTestIsolation `
                              -TestType $testType `
                              -appName $appName `
                              -TestRunnerCodeunitId $testRunnerCodeunitId `
                              -DisabledTests $disabledtests `
                              -XUnitResultFileName $XUnitResultFileName `
                              -AppendToXUnitResultFile:$AppendToXUnitResultFile `
                              -JUnitResultFileName $JUnitResultFileName `
                              -AppendToJUnitResultFile:$AppendToJUnitResultFile `
                              -ReRun:$ReRun `
                              -AzureDevOps $AzureDevOps `
                              -GitHubActions $GitHubActions `
                              -detailed:$detailed `
                              -debugMode:$debugMode `
                              -testPage $testPage `
                              -connectFromHost:$connectFromHost
                }
                catch {
                    Write-Host $_.ScriptStackTrace
                    throw
                }
                finally {
                    if ($clientContext) {
                        Remove-ClientContext -clientContext $clientContext
                    }
                }
            }
            else {
                $containerXUnitResultFileName = ""
                if ($XUnitResultFileName) {
                    $containerXUnitResultFileName = Get-BcContainerPath -containerName $containerName -path $XUnitResultFileName
                    if ("$containerXUnitResultFileName" -eq "") {
                        throw "The path for XUnitResultFileName ($XUnitResultFileName) is not shared with the container."
                    }
                }

                $containerJUnitResultFileName = ""
                if ($JUnitResultFileName) {
                    $containerJUnitResultFileName = Get-BcContainerPath -containerName $containerName -path $JUnitResultFileName
                    if ("$containerJUnitResultFileName" -eq "") {
                        throw "The path for JUnitResultFileName ($JUnitResultFileName) is not shared with the container."
                    }
                }

                $result = Invoke-ScriptInBcContainer -containerName $containerName -usePwsh ($version.Major -ge 26) -scriptBlock { Param([string] $tenant, [string] $companyName, [string] $profile, [System.Management.Automation.PSCredential] $credential, [string] $accessToken, [string] $testSuite, [string] $testGroup, [string] $testCodeunit, [string] $testCodeunitRange, [string] $testFunction, [string] $PsTestFunctionsPath, [string] $ClientContextPath, [string] $XUnitResultFileName, [bool] $AppendToXUnitResultFile, [string] $JUnitResultFileName, [bool] $AppendToJUnitResultFile, [bool] $ReRun, [string] $AzureDevOps, [string] $GitHubActions, [bool] $detailed, [timespan] $interactionTimeout, $testPage, $version, $culture, $timezone, $debugMode, $usePublicWebBaseUrl, $useUrl, $extensionId, $requiredTestIsolation, $testType, $appName, $testRunnerCodeunitId, $disabledtests, $renewClientContextBetweenTests)
    
                    $newtonSoftDllPath = "C:\Program Files\Microsoft Dynamics NAV\*\Service\Management\Newtonsoft.Json.dll"
                    if (!(Test-Path $newtonSoftDllPath)) {
                        $newtonSoftDllPath = "C:\Program Files\Microsoft Dynamics NAV\*\Service\Newtonsoft.Json.dll"
                    }
                    $newtonSoftDllPath = (Get-Item $newtonSoftDllPath).FullName
                    $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
                    $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
                    [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
                    $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value.TrimEnd('/')
                    $clientServicesCredentialType = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
                
                    if ($useUrl) {
                        $serviceUrl = "$($useUrl.TrimEnd('/'))/cs?tenant=$tenant"
                    }
                    elseif ($usePublicWebBaseUrl) {
                        $serviceUrl = "$publicWebBaseUrl/cs?tenant=$tenant"
                    } 
                    else {
                        $uri = [Uri]::new($publicWebBaseUrl)
                        $serviceUrl = "$($Uri.Scheme)://localhost:$($Uri.Port)$($Uri.PathAndQuery)/cs?tenant=$tenant"
                    }
            
                    if ($accessToken) {
                        $clientServicesCredentialType = "AAD"
                        $credential = New-Object pscredential $credential.UserName, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)
                    }
                    elseif ($clientServicesCredentialType -eq "Windows") {
                        $windowsUserName = whoami
                        $allUsers = @(Get-NAVServerUser -ServerInstance $ServerInstance -tenant $tenant -ErrorAction Ignore)
                        if ($allUsers.count -gt 0) {
                            $NavServerUser = $allUsers | Where-Object { $_.UserName -eq $windowsusername }
                            if (!($NavServerUser)) {
                                Write-Host "Creating $windowsusername as user"
                                New-NavServerUser -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername
                                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername -PermissionSetId SUPER
                            }
                        }
                    }
            
                    if ($companyName) {
                        $serviceUrl += "&company=$([Uri]::EscapeDataString($companyName))"
                    }

                    if ($profile) {
                        $serviceUrl += "&profile=$([Uri]::EscapeDataString($profile))"
                    }

                    . $PsTestFunctionsPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath

                    Write-Host "Connecting to $serviceUrl"
                    $clientContext = $null
                    try {

                        Disable-SslVerification

                        $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

                        $Param = @{}
                        if ($renewClientContextBetweenTests) {
                            $Param = @{ "renewClientContext" = { 
                                    if ($renewClientContextBetweenTests) {
                                        Write-Host "Renewing Client Context"
                                        Remove-ClientContext -clientContext $clientContext
                                        $clientContext = $null
                                        $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode
                                        Write-Host "Client Context renewed"
                                    }
                                    $clientContext
                                }
                            }
                        }

                        Run-Tests @Param -clientContext $clientContext `
                                  -TestSuite $testSuite `
                                  -TestGroup $testGroup `
                                  -TestCodeunit $testCodeunit `
                                  -TestCodeunitRange $testCodeunitRange `
                                  -TestFunction $testFunction `
                                  -ExtensionId $extensionId `
                                  -RequiredTestIsolation $requiredTestIsolation `
                                  -TestType $testType `
                                  -appName $appName `
                                  -TestRunnerCodeunitId $testRunnerCodeunitId `
                                  -DisabledTests $disabledtests `
                                  -XUnitResultFileName $XUnitResultFileName `
                                  -AppendToXUnitResultFile:$AppendToXUnitResultFile `
                                  -JUnitResultFileName $JUnitResultFileName `
                                  -AppendToJUnitResultFile:$AppendToJUnitResultFile `
                                  -ReRun:$ReRun `
                                  -AzureDevOps $AzureDevOps `
                                  -GitHubActions $GitHubActions `
                                  -detailed:$detailed `
                                  -debugMode:$debugMode `
                                  -testPage $testPage `
                                  -connectFromHost:$connectFromHost
                    }
                    catch {
                        Write-Host $_.ScriptStackTrace
                        throw
                    }
                    finally {
                        Enable-SslVerification
                        if ($clientContext) {
                            Remove-ClientContext -clientContext $clientContext
                            $clientContext = $null
                        }
                    }
            
                } -argumentList $tenant, $companyName, $profile, $credential, $accessToken, $testSuite, $testGroup, $testCodeunit, $testCodeunitRange, $testFunction, (Get-BcContainerPath -containerName $containerName -Path $PsTestFunctionsPath), (Get-BCContainerPath -containerName $containerName -path $ClientContextPath), $containerXUnitResultFileName, $AppendToXUnitResultFile, $containerJUnitResultFileName, $AppendToJUnitResultFile, $ReRun, $AzureDevOps, $GitHubActions, $detailed, $interactionTimeout, $testPage, $version, $culture, $timezone, $debugMode, $usePublicWebBaseUrl, $useUrl, $extensionId, $requiredTestIsolation, $testType, $appName, $testRunnerCodeunitId, $disabledtests, $renewClientContextBetweenTests.IsPresent
            }
            if ($result -is [array]) {
                0..($result.Count-2) | % { Write-Host $result[$_] }
                $allPassed = $result[$result.Count-1]
            }
            else {
                $allPassed = $result
            }

            if ($returnTrueIfAllPassed) {
                $allPassed
            }
            if (!$allPassed -and $containerName) {
                Remove-BcContainerSession -containerName $containerName
            }
            break
        }
        catch {
            $rethrow = $true
            if ($containerName) {
                Remove-BcContainerSession $containerName
                if ($restartContainerAndRetry) {
                    Write-Host -ForegroundColor Red $_.Exception.Message
                    Restart-BcContainer $containerName
                    if ($useTraefik) {
                        Write-Host "Waiting for 30 seconds to allow Traefik to pickup restarted container"
                        Start-Sleep -Seconds 30
                    }
                    $restartContainerAndRetry = $false
                    $rethrow = $false
                }
            }
            if ($rethrow) {
                if ($debugMode) {
                    Write-host $_.ScriptStackTrace
                }
                throw $_.Exception.Message
            }
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
Set-Alias -Name Run-TestsInNavContainer -Value Run-TestsInBcContainer
Export-ModuleMember -Function Run-TestsInBcContainer -Alias Run-TestsInNavContainer
