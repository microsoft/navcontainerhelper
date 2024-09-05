﻿<#
 .Synopsis
  Function for setting Application Insights Key on a Business Central online environment
 .Description
  Function for setting Application Insights Key on a Business Central online environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the new environment on which you want to set the Application Insights Key
 .Parameter apiVersion
  API version. Default is v2.3.
 .Parameter applicationInsightsKey
  The Application Insights key
 .Example
  Set-BcEnvironmentApplicationInsightsKey -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -environment $environment -applicationInsightsKey $applicationInsightsKey
#>
function Set-BcEnvironmentApplicationInsightsKey {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "v2.3",
        [string] $applicationInsightsKey = "",
        [switch] $doNotWait
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{
            "Authorization" = $bearerAuthValue
        }
        $body = @{
            "key" = $applicationInsightsKey
        }
        Write-Host "Submitting new Application Insights Key for $applicationFamily/$environment"
        $body | ConvertTo-Json | Out-Host
        try {
            Invoke-RestMethod -Method POST -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/applications/$applicationFamily/environments/$environment/settings/appInsightsKey" -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json'
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "New Application Insights Key submitted"
        if (!$doNotWait) {
            Write-Host -NoNewline "Restarting."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $status = (Get-BcEnvironments -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion | Where-Object { $_.name -eq $environment }).status
            } while ($status -eq "Restarting")
            Write-Host $status
            if ($status -ne "Active") {
                throw "Could not create environment"
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
Export-ModuleMember -Function Set-BcEnvironmentApplicationInsightsKey
