﻿<# 
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
 .Parameter InteractionTimeout
  Timespan allowed for a single interaction (Running a test codeunit is an interaction). Default is 24 hours.
 .Parameter culture
  Set the culture when running the tests. Default is en-US. Microsoft tests are written for en-US.
 .Parameter timezone
  Set the timezone when running the tests. Default is current timezone.
 .Parameter debugMode
  Include this switch to output debug information if running the tests fails.
 .Parameter usePublicWebBaseUrl
  Connect to the public Url and not to localhost
 .Parameter connectFromHost
  Run the Test Runner PS functions on the host connecting to the public Web BaseUrl to allow web debuggers like fiddler to trace connections
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the function will run connection test to the online Business Central Environment specified
 .Parameter environment
  Environment to use for the connection test
 .Example
  Run-ConnectionTestsToBcContainer -containerName test -credential $credential
#>
function Run-ConnectionTestToBcContainer {
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
        [timespan] $interactionTimeout = [timespan]::FromHours(24),
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode = $bcContainerHelperConfig.debugMode,
        [switch] $usePublicWebBaseUrl,
        [string] $useUrl = "",
        [switch] $connectFromHost,
        [Hashtable] $bcAuthContext,
        [string] $environment
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    
    $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName
    $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
    $version = [System.Version]($navversion.split('-')[0])

    if ($bcAuthContext -and $environment) {
        $response = Invoke-RestMethod -Method Get -Uri "$($bcContainerHelperConfig.baseUrl.TrimEnd('/'))/$($bcAuthContext.tenantID)/$environment/deployment/url"
        if($response.status -ne 'Ready') {
            throw "environment not ready, status is $($response.status)"
        }
        $useUrl = $response.data.Split('?')[0]
        $tenant = ($response.data.Split('?')[1]).Split('=')[1]
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

    if ($bcAuthContext) {
        $bcAuthContext = Renew-BcAuthContext $bcAuthContext
        $accessToken = $bcAuthContext.accessToken
        $credential = New-Object pscredential -ArgumentList $bcAuthContext.upn, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)
    }

    $PsTestToolFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\PsConnectionTestTool"
    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"

    if (!(Test-Path -Path $PsTestToolFolder -PathType Container)) {
        New-Item -Path $PsTestToolFolder -ItemType Directory | Out-Null
        Copy-Item -Path (Join-Path $PSScriptRoot "PsTestFunctions.ps1") -Destination $PsTestFunctionsPath -Force
        Copy-Item -Path (Join-Path $PSScriptRoot "ClientContext.ps1") -Destination $ClientContextPath -Force
    }

    if ($connectFromHost) {
        $newtonSoftDllPath = Join-Path $PsTestToolFolder "Newtonsoft.Json.dll"
        $clientDllPath = Join-Path $PsTestToolFolder "Microsoft.Dynamics.Framework.UI.Client.dll"
    
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
            }
        } -argumentList $newtonSoftDllPath, $clientDllPath
    
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
    
        $clientContext = $null
        try {
            $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

            Run-ConnectionTest -clientContext $clientContext `
                               -debugMode:$debugMode `
                               -connectFromHost:$connectFromHost
        }
        catch {
            Write-Host $_.ScriptStackTrace
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

        $result = Invoke-ScriptInBcContainer -containerName $containerName -usePwsh $false -scriptBlock { Param([string] $tenant, [string] $companyName, [string] $profile, [pscredential] $credential, [string] $accessToken, [string] $PsTestFunctionsPath, [string] $ClientContextPath, [timespan] $interactionTimeout, $version, $culture, $timezone, $debugMode, $usePublicWebBaseUrl, $useUrl)
    
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
                $serviceUrl = "$($Uri.Scheme)://localhost:$($Uri.Port)/$($Uri.PathAndQuery)/cs?tenant=$tenant"
            }
    
            if ($accessToken) {
                $clientServicesCredentialType = "AAD"
                $credential = New-Object pscredential $credential.UserName, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)
            }
            elseif ($clientServicesCredentialType -eq "Windows") {
                $windowsUserName = whoami
                $NavServerUser = Get-NAVServerUser -ServerInstance $ServerInstance -tenant $tenant -ErrorAction Ignore | Where-Object { $_.UserName -eq $windowsusername }
                if (!($NavServerUser)) {
                    Write-Host "Creating $windowsusername as user"
                    New-NavServerUser -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername
                    New-NavServerUserPermissionSet -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername -PermissionSetId SUPER
                }
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

                Disable-SslVerification

                $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

                Run-ConnectionTest -clientContext $clientContext `
                                   -debugMode:$debugMode `
                                   -connectFromHost:$connectFromHost
            }
            catch {
                Write-Host $_.ScriptStackTrace
                if ($debugMode -and $clientContext) {
                    Dump-ClientContext -clientcontext $clientContext 
                }
                throw
            }
            finally {
                Enable-SslVerification
                if ($clientContext) {
                    Remove-ClientContext -clientContext $clientContext
                    $clientContext = $null
                }
            }
    
        } -argumentList $tenant, $companyName, $profile, $credential, $accessToken, (Get-BcContainerPath -containerName $containerName -Path $PsTestFunctionsPath), (Get-BCContainerPath -containerName $containerName -path $ClientContextPath), $interactionTimeout, $version, $culture, $timezone, $debugMode, $usePublicWebBaseUrl, $useUrl
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
Set-Alias -Name Run-ConnectionTestToNavContainer -Value Run-ConnectionTestToBcContainer
Export-ModuleMember -Function Run-ConnectionTestToBcContainer -Alias Run-ConnectionTestToNavContainer
