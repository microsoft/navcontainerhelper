<# 
 .Synopsis
  Function for installing an AppSource App in an online Business Central environment
 .Description
  Function for installing an AppSource App in an online Business Central environment
  Current implementation uses client service to invoke page 2503 and install the app
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter environment
  Environment in which you want to install an AppSource App
 .Parameter appId
  AppId of the AppSource App you want to install
 .Parameter appVersion
  Version of the AppSource App you want to install
 .Parameter languageId
  languageId
 .Parameter acceptIsvEula
  By including this switch you acknowledge that you have read and accept the Isv Eula
 .Parameter installOrUpdateNeededDependencies
  Include this switch to Install or Update needed dependencies
 .Parameter allowInstallationOnProduction
  Include this switch if you want to allow this function to install AppSource apps on a production environment
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Install-BcAppFromAppSource -bcAuthContext $authContext -AppId '55ba54a3-90c7-4d3f-bc73-68eaa51fd5f8' -acceptIsvEula
#>
function Install-BcAppFromAppSource {
    Param (
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$true)]
        [string] $appId,
        [string] $appVersion = "",
        [string] $languageId = "",
        [switch] $acceptIsvEula,
        [switch] $installOrUpdateNeededDependencies,
        [switch] $allowInstallationOnProduction
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.Name -eq $environment }
    if (!$bcEnvironment) {
        throw "Environment $environment doesn't exist in the current context."
    }
    if ($bcEnvironment.Type -eq 'Production' -and !$allowInstallationOnProduction) {
        throw "If you want to install an app in a production environment, you need to specify -allowInstallOnProduction"
    }
    $appExists = Get-BcPublishedApps -bcAuthContext $bcauthcontext -environment $environment | Where-Object { $_.id -eq $appid -and $_.state -eq "installed" }
    if ($appExists) {
        Write-Host -ForegroundColor Green "App $($appExists.Name) from $($appExists.Publisher) version $($appExists.Version) is already installed"
    }
    else {
        $response = Invoke-RestMethod -Method Get -Uri "https://businesscentral.dynamics.com/$($bcAuthContext.tenantID)/$environment/deployment/url"
        if($response.status -ne 'Ready') {
            throw "environment not ready, status is $($response.status)"
        }

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }
        $body = @{ "AcceptIsvEula" = $acceptIsvEula.ToBool() }
        if ($appVersion) { $body += @{ "targetVersion" = $appVersion } }
        if ($languageId) { $body += @{ "languageId" = $languageId } }
        if ($installOrUpdateNeededDependencies) { $body += @{ "installOrUpdateNeededDependencies" = $installOrUpdateNeededDependencies.ToBool() } }
    
        Write-Host "Installing $appId $appVersion on $($environment)"
        try {
            $operation = Invoke-RestMethod -Method Post -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.6/applications/BusinessCentral/environments/$environment/apps/$appId/install" -Headers $headers -ContentType "application/json" -Body ($body | ConvertTo-Json)
        }
        catch {
            throw (GetExtenedErrorMessage $_.Exception)
        }
    
        Write-Host "Operation ID $($operation.id)"
        $status = $operation.status
        Write-Host -NoNewline "$($status)."
        $completed = $operation.Status -eq "succeeded"
        $errCount = 0
        while (-not $completed) {
            Start-Sleep -Seconds 3
            try {
                $appInstallStatusResponse = Invoke-WebRequest -Headers $headers -Method Get -Uri "https://api.businesscentral.dynamics.com/admin/v2.6/applications/BusinessCentral/environments/$environment/apps/$appId/operations" -UseBasicParsing
                $appInstallStatus = (ConvertFrom-Json $appInstallStatusResponse.Content).value | Where-Object { $_.id -eq $operation.id }
                if ($status -ne $appInstallStatus.status) {
                    Write-Host
                    Write-Host -NoNewline "$($appInstallStatus.status)"
                    $status = $appInstallStatus.status
                }
                $completed = $status -eq "succeeded"
                if ($status -eq "running" -or $status -eq "scheduled") {
                    Write-Host -NoNewline "."
                }
                elseif (!$completed) {
                    $errorMessage = $status
                    try {
                        (ConvertFrom-Json $appInstallStatusResponse.Content).value | Where-Object { $_.id -eq $operation.id } | % { $errorMessage = $_.errorMessage }
                    } catch {}
                    throw $errorMessage
                }
                $errCount = 0
            }
            catch {
                if ($errCount++ -gt 3) {
                    throw (GetExtenedErrorMessage $_.Exception)
                }
                $completed = $false
            }
        }
        Write-Host
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
Export-ModuleMember -Function Install-BcAppFromAppSource
