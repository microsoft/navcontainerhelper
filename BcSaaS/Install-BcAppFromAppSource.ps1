<# 
 .Synopsis
  Function for installing an AppSource App in an online Business Central environment
 .Description
  Function for installing an AppSource App in an online Business Central environment
  Current implementation uses client service to invoke page 2503 and install the app
  WARNING: The implementation of this function will change when admin center API contains functionality for this
 .Parameter containerName
  ContainerName from which the client service connection is created (this parameter will be removed later)
 .Parameter companyName
  Company name in which the client service connection is done (this parameter will be removed later)
 .Parameter profile
  Profile name for the user which is performing the client service connection (this parameter will be removed later)
 .Parameter culture
  Culture of the user performing the client service connection (this parameter will be removed later)
 .Parameter timeZone
  Timezone of the user performing the client service connection  (this parameter will be removed later)
 .Parameter debugMode
  Include this switch if you want to enable debugMode for the client Service connection (this parameter will be removed later)
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter environment
  Environment in which you want to install an AppSource App
 .Parameter appId
  AppId of the AppSource App you want to install
 .Parameter appId
  Name of the AppSource App you want to install
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Install-BcAppFromAppSource -containerName proxy -bcAuthContext $authContext -AppId '55ba54a3-90c7-4d3f-bc73-68eaa51fd5f8'
#>
function Install-BcAppFromAppSource {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $companyName = "",
        [string] $profile = "",
        [timespan] $interactionTimeout = [timespan]::FromHours(24),
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode,
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$true)]
        [string] $appId,
        [string] $appName = $appId,
        [switch] $connectFromHost,
        [switch] $allowInstallationOnProduction
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.Name -eq $environment }
    if (!$bcEnvironment) {
        throw "Environment $environment doesn't exist in the current context."
    }
    if ($bcEnvironment.Type -eq 'Production' -and !$allowInstallationOnProduction) {
        throw "If you want to install an app in a production environment, you need to specify -allowInstallOnProduction"
    }
    
    Write-Host -ForegroundColor Yellow "NOTE: The implementation of Install-BcAppFromAppSource will be replaced by the Admin Center API implementation when available"

    $appExists = Get-BcPublishedApps -bcAuthContext $bcauthcontext -environment $environment | Where-Object { $_.id -eq $appid -and $_.state -eq "installed" }
    if ($appExists) {
        Write-Host -ForegroundColor Green "App $($appExists.Name) from $($appExists.Publisher) version $($appExists.Version) is already installed"
    }
    else {
        $response = Invoke-RestMethod -Method Get -Uri "https://businesscentral.dynamics.com/$($bcAuthContext.tenantID)/$environment/deployment/url"
        if($response.status -ne 'Ready') {
            throw "environment not ready, status is $($response.status)"
        }
        $useUrl = $response.data.Split('?')[0]
        $tenant = ($response.data.Split('?')[1]).Split('=')[1]

        $PsTestToolFolder = Join-Path $extensionsFolder "$containerName\PsConnectionTestTool"
        CreatePsTestToolFolder -containerName $containerName -PsTestToolFolder $PsTestToolFolder
    
        $serviceUrl = "$($useUrl.TrimEnd('/'))/cs?tenant=$tenant"
        $credential = New-Object pscredential 'user', (ConvertTo-SecureString -String $bcAuthContext.AccessToken -AsPlainText -Force)
    
        if ($companyName) { $serviceUrl += "&company=$([Uri]::EscapeDataString($companyName))" }
        if ($profile) { $serviceUrl += "&profile=$([Uri]::EscapeDataString($profile))" }

        if ($connectFromHost) {
    
            . (Join-Path $PsTestToolFolder "PsTestFunctions.ps1") -newtonSoftDllPath (Join-Path $PsTestToolFolder "NewtonSoft.json.dll") -clientDllPath (Join-Path $PsTestToolFolder "Microsoft.Dynamics.Framework.UI.Client.dll") -clientContextScriptPath (Join-Path $PsTestToolFolder "ClientContext.ps1")
        
            $clientContext = $null
            try {
                $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth 'AAD' -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode

                Install-AppSourceApp -clientContext $clientContext -debugMode:$debugMode -connectFromHost:$connectFromHost -appId $appId -appName $appName
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
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param ($psTestToolFolder, $serviceUrl, $interactionTimeout, $culture, $timezone, $credential, $appId, $appName, $debugMode, $connectFromHost)

                $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
                $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"

                . (Join-Path $PsTestToolFolder "PsTestFunctions.ps1") -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath (Join-Path $PsTestToolFolder "ClientContext.ps1")
            
                $clientContext = $null
                try {
                    $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth 'AAD' -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode
    
                    Install-AppSourceApp -clientContext $clientContext -debugMode:$debugMode -connectFromHost:$connectFromHost -appId $appId -appName $appName
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


            } -argumentList (Get-BcContainerPath -containerName $containerName -path $PsTestToolFolder), $serviceUrl, $interactionTimeout, $culture, $timezone, $credential, $appId, $appName, $debugMode, $connectFromHost
        }
    }
}
Export-ModuleMember -Function Install-BcAppFromAppSource
