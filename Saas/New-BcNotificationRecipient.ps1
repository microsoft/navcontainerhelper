<#
 .Synopsis
  Function for creatig a notification recipient for a Business Central tenant.
 .Description
  Function for creating a notification recipient for a Business Central tenant.
  Submit Email and Name.
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_notifications#create-notification-recipient
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter apiVersion
  API version. Default is v2.15.
 .Example
  $bcauthContext = New-BcAuthContext -includeDeviceLogin
  New-BcNotificationRecipient -bcAuthContext $bcAuthContext -NotificationRecipientMail $Email -NotificationRecipientName $Name
#>

function New-BcNotificationRecipient {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] 
        $bcAuthContext,
        [string] 
        $apiVersion = "v2.6",
        [string] 
        $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [String]
        $NotificationRecipientMail,
        [Parameter(Mandatory = $true)]
        [String]
        $NotificationRecipientName
    )

    $body = @{ "Name" = $NotificationRecipientName }
    $body += @{ "Email" = $NotificationRecipientMail }

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
        try {
            Invoke-RestMethod -Method Put -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/settings/notification/recipients" -Headers $headers -ContentType "application/json" -Body ($body | ConvertTo-Json)
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
Export-ModuleMember -Function New-BcNotificationRecipient