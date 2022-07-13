<# 
 .Synopsis
  Get information about updates that have already been scheduled for a specific environment.
 .Description
  Get information about updates that have already been scheduled for a specific environment.
  Wrapper for https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_reschedule_updates#get-scheduled-update
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Environment from which you want to return the scheduled upgrade information.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcScheduledUpgrade -bcAuthContext $authContext -environment "Sandbox"
#>

function Get-BcScheduledUpgrade {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",     
        [Parameter(Mandatory = $true)]
        [string] $environment
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }
        try {
            Invoke-RestMethod -Method Get -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/v2.3/applications/$applicationFamily/environments/$environment/upgrade" -Headers $headers
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
Export-ModuleMember -Function Get-BcScheduledUpgrade