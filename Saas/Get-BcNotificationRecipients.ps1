<#
 .Synopsis
  Function for retrieving the notification recipients configured for a Business Central tenant.
 .Description
  Function for retrieving the notification recipients configured for a Business Central tenant.
  Returns Id, Email and Name configured for each notification recipient.
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_notifications#get-notification-recipients
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter apiVersion
  API version. Default is v2.15.
 .Example
  $bcauthContext = New-BcAuthContext -includeDeviceLogin
  Get-BcNotificationRecipients -bcAuthContext $bcauthContext
#>

function Get-BcNotificationRecipients {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] 
        $bcAuthContext,
        [string] 
        $apiVersion = "v2.6",
        [string] 
        $applicationFamily = "BusinessCentral"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
        try {
            (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/settings/notification/recipients" -Headers $headers).Value
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
Export-ModuleMember -Function Get-BcNotificationRecipients