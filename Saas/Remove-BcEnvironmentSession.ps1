<#
 .Synopsis
  Function for stopping and deletion of session from environment (from an online Business Central tenant)
 .Description
  Function for stop and deletion of session from environment (from an online Business Central tenant)
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_session_management#stop-and-delete-a-session
 .Parameter SessionID
  Session ID of session to be stopped and deleted.
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment
 .Parameter apiVersion
  API version. Default is v2.21.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Remove-BcEnvironmentSession  -bcAuthContext $authContext -environment "MySandbox"
#>
function Remove-BcEnvironmentSession {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory = $true)]
        [string] $sessionID,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment = "",
        [string] $apiversion = "v2.21"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "sessions/$sessionID" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion

        Write-Host "Submitting session deletion request for session ID $sessionID in $environment"

        try {
            $Result = (Invoke-RestMethod -Method Delete -UseBasicParsing -Uri $endPointURL -Headers $headers)

        }
        catch {
            Write-Host $_
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "Session deletion request submitted"

    }


    catch {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
        throw
    }
    finally {
        TrackTrace -telemetryScope $telemetryScope
    }
}

Export-ModuleMember -Function Remove-BcEnvironmentSession
