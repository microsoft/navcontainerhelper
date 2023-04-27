<#
 .Synopsis
  Function for setting Update Window on a Business Central online environment
 .Description
  Function for setting Update Window on a Business Central online environment.
  The Update Window has to be at least 6 hours long.
  If the Parameter timeZoneId is not set, the timezone set in the target Business Central Environment will be used.
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment which you want to set the Update Window for
 .Parameter apiVersion
  API version. Default is v2.18.
 .Parameter preferredStartTime
  Start of environment update window (Format HH:mm, 30 minute increments; validation implemented)
 .Parameter preferredEndTime
  End of environment update window (Format HH:mm, 30 minute increments; validation implemented)
 .Parameter timeZoneId
  Timezone in Windows default format, e.g. "W. Europe Standard Time"
  If set, the timezone for the environment update window is set accordingly.  
  If not set, default timezone from the target environment is used
 .Example
  $bcauthContext = New-BcAuthContext -includeDeviceLogin
  Set-BcEnvironmentUpdateWindow -bcAuthContext $bcAuthContext -environment "Sandbox" -preferredStartTime "22:00" -preferredEndTime "05:00" -timeZoneId "W. Europe Standard Time"
#>
function Set-BcEnvironmentUpdateWindow {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "v2.18",
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^([0-1]?[0-9]|2[0-3]):(00|30)$")] 
        [string] $preferredStartTime,
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^([0-1]?[0-9]|2[0-3]):(00|30)$")] 
        [string] $preferredEndTime,
        [string] $timeZoneId
    )

    $body = @{ "preferredStartTime" = $preferredStartTime }
    $body += @{ "preferredEndTime" = $preferredEndTime }

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
        if ([string]::IsNullOrEmpty($timeZoneId)) {
            $timeZoneResult = Get-BcEnvironmentUpdateWindow -bcAuthContext $bcAuthContext -environment $environment
            $timeZoneId = $timeZoneResult.timeZoneId
        }

        $body += @{ "timeZoneId" = $timeZoneId }

        try {
            Invoke-RestMethod -Method Put -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/applications/$applicationFamily/environments/$environment/settings/upgrade" -Headers $headers -ContentType "application/json" -Body ($body | ConvertTo-Json)
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
Export-ModuleMember -Function Set-BcEnvironmentUpdateWindow
