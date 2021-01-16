<# 
 .Synopsis
  Preview function for installing an AppSource App in an online tenant
 .Description
  Preview function for installing an AppSource App in an online tenant
#>
function Install-BcAppFromAppSource {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $companyName = "",
        [string] $profile = "",
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [timespan] $interactionTimeout = [timespan]::FromHours(24),
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode,
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
