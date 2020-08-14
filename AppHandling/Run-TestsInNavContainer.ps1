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
 .Parameter accesstoken
  If your container is running AAD authentication, you need to specify an accesstoken for the user specified in credential
 .Parameter testSuite
  Name of test suite to run. Default is DEFAULT.
 .Parameter testGroup
  Only supported in 14.x containers or older. Name of test group to run. Wildcards (? and *) are supported. Default is *.
 .Parameter testCodeunit
  Name or ID of test codeunit to run. Wildcards (? and *) are supported. Default is *.
 .Parameter testFunction
  Name of test function to run. Wildcards (? and *) are supported. Default is *.
 .Parameter XUnitResultFileName
  Filename where the function should place an XUnit compatible result file
 .Parameter AppendToXUnitResultFile
  Specify this switch if you want the function to append to the XUnit compatible result file instead of overwriting it
 .Parameter ReRun
  Specify this switch if you want the function to replace an existing test run (of the same test codeunit) in the XUnit compatible result file instead of adding it
 .Parameter AzureDevOps
  Generate Azure DevOps Pipeline compatible output. This setting determines the severity of errors.
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
 .Parameter restartContainerAndRetry
  Include this switch to restart container and retry the operation (everything) on non-recoverable errors.
  This is NOT test failures, but more things like out of memory, communication errors or that kind.
 .Parameter connectFromHost
  Run the Test Runner PS functions on the host connecting to the public Web BaseUrl to allow web debuggers like fiddler to trace connections
 .Example
  Run-TestsInBcContainer -contatinerName test -credential $credential
 .Example
  Run-TestsInBcContainer -contatinerName $containername -credential $credential -XUnitResultFileName "c:\ProgramData\BcContainerHelper\$containername.results.xml" -AzureDevOps "warning"
#>
function Run-TestsInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [string] $companyName = "",
        [Parameter(Mandatory=$false)]
        [string] $profile = "",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [Parameter(Mandatory=$false)]
        [string] $accessToken = "",
        [Parameter(Mandatory=$false)]
        [string] $testSuite = "DEFAULT",
        [Parameter(Mandatory=$false)]
        [string] $testGroup = "*",
        [Parameter(Mandatory=$false)]
        [string] $testCodeunit = "*",
        [Parameter(Mandatory=$false)]
        [string] $testFunction = "*",
        [string] $extensionId = "",
        [array]  $disabledTests = @(),
        [Parameter(Mandatory=$false)]
        [string] $XUnitResultFileName,
        [switch] $AppendToXUnitResultFile,
        [switch] $ReRun,
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no',
        [switch] $detailed,
        [timespan] $interactionTimeout = [timespan]::FromHours(24),
        [switch] $returnTrueIfAllPassed,
        [Parameter(Mandatory=$false)]
        [int] $testPage,
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode,
        [switch] $restartContainerAndRetry,
        [switch] $usePublicWebBaseUrl,
        [string] $useUrl = "",
        [switch] $connectFromHost
    )
    
    $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
    $version = [System.Version]($navversion.split('-')[0])

    $useTraefik = $false
    $inspect = docker inspect $containerName | ConvertFrom-Json
    if ($inspect.Config.Labels.psobject.Properties.Match('traefik.enable').Count -gt 0) {
        if ($inspect.config.Labels.'traefik.enable' -eq "true") {
            $usePublicWebBaseUrl = ($useUrl -eq "")
            $useTraefik = $true
        }
    }

    $PsTestToolFolder = Join-Path $extensionsFolder "$containerName\PsTestTool-6"
    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"
    $fobfile = Join-Path $PsTestToolFolder "PSTestToolPage.fob"
    $serverConfiguration = Get-BcContainerServerConfiguration -ContainerName $containerName
    $clientServicesCredentialType = $serverConfiguration.ClientServicesCredentialType

    if ($usePublicWebBaseUrl -and $useUrl -ne "") {
        throw "You cannot specify usePublicWebBaseUrl and useUrl at the same time"
    }

    if ($serverConfiguration.PublicWebBaseUrl -eq "") {
        throw "Container $containerName needs to include the WebClient in order to run tests (PublicWebBaseUrl is blank)"
    }

    if ($useUrl -eq "") {
        if ([bool]($serverConfiguration.PSobject.Properties.name -eq "EnableTaskScheduler")) {
            if ($serverConfiguration.EnableTaskScheduler -eq "True") {
                Write-Host -ForegroundColor Red "WARNING: TaskScheduler is running in the container. Please specify -EnableTaskScheduler:`$false when creating container."
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
                    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential
                }
            }
        } catch {
            Remove-Item -Path $PsTestToolFolder -Recurse -Force
            throw
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

    while ($true) {
        try
        {
            if ($connectFromHost) {
                $newtonSoftDllPath = Join-Path $PsTestToolFolder "NewtonSoft.json.dll"
                $clientDllPath = Join-Path $PsTestToolFolder "Microsoft.Dynamics.Framework.UI.Client.dll"
    
                Invoke-ScriptInBcContainer -containerName $containerName { Param([string] $myNewtonSoftDllPath, [string] $myClientDllPath)
                
                    $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
                    if (!(Test-Path $myNewtonSoftDllPath)) {
                        Copy-Item -Path $newtonSoftDllPath -Destination $myNewtonSoftDllPath
                    }
                    $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
                    if (!(Test-Path $myClientDllPath)) {
                        Copy-Item -Path $clientDllPath -Destination $myClientDllPath
                    }
                } -argumentList $newtonSoftDllPath, $clientDllPath
    
                $config = Get-BcContainerServerConfiguration -ContainerName $containerName
                if ($useUrl) {
                    $publicWebBaseUrl = $useUrl.TrimEnd('/')
                }
                else {
                    $publicWebBaseUrl = $config.PublicWebBaseUrl.TrimEnd('/')
                }
                $clientServicesCredentialType = $config.ClientServicesCredentialType
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
        
                $clientContext = $null
                try {
                    $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

                    $result = Run-Tests -clientContext $clientContext `
                              -TestSuite $testSuite `
                              -TestGroup $testGroup `
                              -TestCodeunit $testCodeunit `
                              -TestFunction $testFunction `
                              -ExtensionId $extensionId `
                              -DisabledTests $disabledtests `
                              -XUnitResultFileName $XUnitResultFileName `
                              -AppendToXUnitResultFile:$AppendToXUnitResultFile `
                              -ReRun:$ReRun `
                              -AzureDevOps $AzureDevOps `
                              -detailed:$detailed `
                              -debugMode:$debugMode `
                              -testPage $testPage
                }
                catch {
                    if ($debugMode -and $clientContext) {
                        Dump-ClientContext -clientcontext $clientContext 
                    }
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

                $result = Invoke-ScriptInBcContainer -containerName $containerName { Param([string] $tenant, [string] $companyName, [string] $profile, [pscredential] $credential, [string] $accessToken, [string] $testSuite, [string] $testGroup, [string] $testCodeunit, [string] $testFunction, [string] $PsTestFunctionsPath, [string] $ClientContextPath, [string] $XUnitResultFileName, [bool] $AppendToXUnitResultFile, [bool] $ReRun, [string] $AzureDevOps, [bool] $detailed, [timespan] $interactionTimeout, $testPage, $version, $culture, $timezone, $debugMode, $usePublicWebBaseUrl, $useUrl, $extensionId, $disabledtests)
    
                    $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
                    $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
                    $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
                    [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
                    $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value.TrimEnd('/')
                    $clientServicesCredentialType = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
                
                    if ($useUrl) {
                        $disableSslVerification = $false
                        $serviceUrl = "$($useUrl.TrimEnd('/'))/cs?tenant=$tenant"
                    }
                    elseif ($usePublicWebBaseUrl) {
                        $disableSslVerification = $false
                        $serviceUrl = "$publicWebBaseUrl/cs?tenant=$tenant"
                    } 
                    else {
                        $uri = [Uri]::new($publicWebBaseUrl)
                        $disableSslVerification = ($Uri.Scheme -eq "https")
                        $serviceUrl = "$($Uri.Scheme)://localhost:$($Uri.Port)/$($Uri.PathAndQuery)/cs?tenant=$tenant"
                    }
            
                    if ($clientServicesCredentialType -eq "Windows") {
                        $windowsUserName = whoami
                        $NavServerUser = Get-NAVServerUser -ServerInstance $ServerInstance -tenant $tenant -ErrorAction Ignore | Where-Object { $_.UserName -eq $windowsusername }
                        if (!($NavServerUser)) {
                            Write-Host "Creating $windowsusername as user"
                            New-NavServerUser -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername
                            New-NavServerUserPermissionSet -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername -PermissionSetId SUPER
                        }
                    }
                    elseif ($accessToken) {
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

                    $clientContext = $null
                    try {

                        if ($disableSslVerification) {
                            Disable-SslVerification
                        }

                        $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

                        Run-Tests -clientContext $clientContext `
                                  -TestSuite $testSuite `
                                  -TestGroup $testGroup `
                                  -TestCodeunit $testCodeunit `
                                  -TestFunction $testFunction `
                                  -ExtensionId $extensionId `
                                  -DisabledTests $disabledtests `
                                  -XUnitResultFileName $XUnitResultFileName `
                                  -AppendToXUnitResultFile:$AppendToXUnitResultFile `
                                  -ReRun:$ReRun `
                                  -AzureDevOps $AzureDevOps `
                                  -detailed:$detailed `
                                  -debugMode:$debugMode `
                                  -testPage $testPage
                    }
                    catch {
                        if ($debugMode -and $clientContext) {
                            Dump-ClientContext -clientcontext $clientContext 
                        }
                        throw
                    }
                    finally {
                        if ($disableSslVerification) {
                            Enable-SslVerification
                        }
                        if ($clientContext) {
                            Remove-ClientContext -clientContext $clientContext
                            $clientContext = $null
                        }
                    }
            
                } -argumentList $tenant, $companyName, $profile, $credential, $accessToken, $testSuite, $testGroup, $testCodeunit, $testFunction, (Get-BcContainerPath -containerName $containerName -Path $PsTestFunctionsPath), (Get-BCContainerPath -containerName $containerName -path $ClientContextPath), $containerXUnitResultFileName, $AppendToXUnitResultFile, $ReRun, $AzureDevOps, $detailed, $interactionTimeout, $testPage, $version, $culture, $timezone, $debugMode, $usePublicWebBaseUrl, $useUrl, $extensionId, $disabledtests
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
            if (!$allPassed) {
                Remove-BcContainerSession -containerName $containerName
            }
            break
        }
        catch {
            Remove-BcContainerSession $containerName
            if ($restartContainerAndRetry) {
                Write-Host -ForegroundColor Red $_.Exception.Message
                Restart-BcContainer $containerName
                if ($useTraefik) {
                    Write-Host "Waiting for 30 seconds to allow Traefik to pickup restarted container"
                    Start-Sleep -Seconds 30
                }
                $restartContainerAndRetry = $false
            }
            else {
                if ($debugMode) {
                    Write-host $_.ScriptStackTrace
                }
                throw $_.Exception.Message
            }
        }
    }
}
Set-Alias -Name Run-TestsInNavContainer -Value Run-TestsInBcContainer
Export-ModuleMember -Function Run-TestsInBcContainer -Alias Run-TestsInNavContainer
