<#
 .Synopsis
  Reschedule an update for a specific environment, if able.
 .Description
  Reschedule an update for a specific environment, if able.
  Wrapper for https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_reschedule_updates#reschedule-update
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Environment for which you want to reschedule an upgrade.
 .Parameter apiVersion
  API version. Default is v2.13.
 .Parameter runOn
  Sets the date that the upgrade should be run on.
  Must be in the allowed time range.
  Time range can be retrieved by running Get-BcScheduledUpgrade.
 .Parameter ignoreUpgradeWindow
  Specifies if the upgrade window for the environment should be ignored. Default is false.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  $ScheduledUpgrade = Get-BcEnvironmentScheduledUpgrade -bcAuthContext $authContext -environment "Sandbox"
  Reschedule-BcEnvironmentUpgrade -bcAuthContext $authContext -environment "Sandbox" -runOn $ScheduledUpgrade.earliestSelectableUpgradeDate
#>

function Reschedule-BcEnvironmentUpgrade {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "v2.13",
        [Parameter(Mandatory = $true)]
        [datetime] $runOn,
        [bool] $ignoreUpgradeWindow = $false
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }
        $body = @{
            runOn               = $runOn
            ignoreUpgradeWindow = $ignoreUpgradeWindow
        }

        Write-Host "Submitting reschedule upgrade request for $applicationFamily/$environment"
        $body | Out-Host

        try {
            Invoke-RestMethod -Method Put -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/applications/$applicationFamily/environments/$environment/upgrade" -Headers $headers -Body $($Body | ConvertTo-Json)  -ContentType 'application/json'
        }
        catch {
            throw (GetExtendedErrorMessage $_)
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
Set-Alias -Name Reschedule-BcUpgrade -Value Reschedule-BcEnvironmentUpgrade
Export-ModuleMember -Function Reschedule-BcEnvironmentUpgrade -Alias Reschedule-BcUpgrade
