<#
 .Synopsis
  Function for setting Update Window on a Business Central online environment
 .Description
  Function for setting Update Window on a Business Central online environment.
  The Update Window has to be at least 6 hours long!
  If the Parameter timeZoneId is not set, the timezone set in the target Business Central Environment will be used.
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the new environment on which you want to set the Update Window for
 .Parameter apiVersion
  API version. Default is v2.18.
 .Parameter preferredStartTime
  Start of environment update window, Format HH:mm, 30 minute increments
 .Parameter preferredEndTime
  End of environment update window, Format HH:mm, 30 minute increments
 .Parameter timeZoneId
  Timezone in Windows default format, e.g. "W. Europe Standard Time"
  If not set, default timeZone from the target environment is used
 .Example
  TBD
  Set-BcEnvironmentUpdateWindow -$bcAuthContext $bcAuthContext -environment $environment -preferredStartTime "22:00" -preeferredEndTime "05:00" -timeZoneId "W. Europe Standard Time"
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
        [ValidatePattern("[00-23]:[00,30]")] 
        [string] $preferredStartTime,
        [Parameter(Mandatory = $true)]
        [ValidatePattern("[00-23]:[00,30]")] 
        [string] $preferredEndTime,
        [string] $timeZoneId
    )

    $body = @{ "preferredStartTime" = $preferredStartTime }
    $body += @{ "preferredEndTime" = $preferredEndTime }

    if($null -ne $timeZoneId){
        $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
        try {
            $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
            try {
                $timeZoneResult = Invoke-RestMethod -Method Get -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/v2.18/applications/businesscentral/environments/Production/settings/upgrade" -Headers $headers
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
        $timeZoneId = $timeZoneResult.timeZoneId
    }

    $body += @{ "timeZoneId" = $timeZoneId }

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
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