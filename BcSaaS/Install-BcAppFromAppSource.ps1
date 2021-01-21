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
        [string] $appName = $appId
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.Name -eq $environment -and $_.Type -eq "Sandbox" }
    if (!$bcEnvironment) {
        throw "Environment $environment doesn't exist in the current context or it is not a Sandbox environment."
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
    
        . (Join-Path $PsTestToolFolder "PsTestFunctions.ps1") -newtonSoftDllPath (Join-Path $PsTestToolFolder "NewtonSoft.json.dll") -clientDllPath (Join-Path $PsTestToolFolder "Microsoft.Dynamics.Framework.UI.Client.dll") -clientContextScriptPath (Join-Path $PsTestToolFolder "ClientContext.ps1")
    
        $clientContext = $null
        try {
            $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth 'AAD' -credential $credential -interactionTimeout $interactionTimeout -culture $culture -timezone $timezone -debugMode:$debugMode
            
            $dialog = $clientContext.OpenFormWithFilter(2503, "ID IS '$appId'")
            $bar = $clientContext.GetControlByName($dialog,"ActionBar")
            $InstallAction = $clientContext.GetActionByName($bar, 'Install')
            Write-Host "Installing $($appName)"
            $page = $clientContext.InvokeActionAndCatchForm($InstallAction)
            if ($page.ControlIdentifier -like "{000009c7-*") {
                Write-Host -NoNewline "Progress."
                $statusPage = $clientContext.OpenForm(2508)
                if (!($statusPage)) {
                    throw "Couldn't open page 2508"
                }
                $repeater = $clientContext.GetControlByType($statusPage, [Microsoft.Dynamics.Framework.UI.Client.ClientRepeaterControl])
                do {
                    Start-Sleep -Seconds 2
                    Write-Host -NoNewline "."
                    $index = 0
                    $clientContext.SelectFirstRow($repeater)
                    $clientContext.Refresh($repeater)
                    $status = "Failed"
                    $row = $null
                    while ($true)
                    {
                        if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
                        {
                            $clientContext.ScrollRepeater($repeater, 1)
                        }
                        $rowIndex = $index - $repeater.Offset
                        $index++
                        if ($rowIndex -ge $repeater.DefaultViewport.Count)
                        {
                            break
                        }
                        $row = $repeater.DefaultViewport[$rowIndex]
                        $nameControl = $clientContext.GetControlByName($row, "Name")
                        $name = $nameControl.StringValue
                        if ($name -like "*$appId*") {
                            $status = $clientContext.GetControlByName($row, "Status").StringValue
                            break
                        }
                    }
                }
                while ($status -eq "InProgress")
    
                if ($row) {
                    if ($status -eq "Completed") {
                        Write-Host -ForegroundColor Green " $status"
                    }
                    else {
                        Write-Host -ForegroundColor Red " $status"
                        $details = $clientContext.InvokeActionAndCatchForm($row)
                        if ($details) {
                            $summaryControl = $clientContext.GetControlByName($details, "OpDetails")
                            if ($summaryControl) {
                                Write-Host -ForegroundColor Red $summaryControl.StringValue
                            }
                            $viewDetailsControl = $clientContext.GetControlByName($details, "Details")
                            if ($viewDetailsControl) {
                                $clientContext.InvokeSystemAction($viewDetailsControl, "DrillDown")
                                $detailsControl = $clientContext.GetControlByName($details, "Detailed Message box")
                                if ($detailsControl -and $detailsControl.StringValue) {
                                    Write-Host -ForegroundColor Red "Error Details: $($detailsControl.StringValue)"
                                }
                            }
                            $clientContext.CloseForm($details)
                        }
                        throw "Could not install $appName"
                    }
                }
            }
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
}
Export-ModuleMember -Function Install-BcAppFromAppSource
