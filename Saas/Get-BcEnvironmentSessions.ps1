<#
 .Synopsis
  Function for retrieving a list of current sessions for given environment from an online Business Central tenant
 .Description
  Function for retrieving a list of current sessions for given environment from an online Business Central tenant
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_session_management#get-active-sessions
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
  Get-BcEnvironmentSessions  -bcAuthContext $authContext -environment "MySandbox"
#>
function Get-BcEnvironmentSessions {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment = "",
        [string] $apiversion = "v2.21"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "sessions" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion
        try {
            $Result = (Invoke-RestMethod -Method Get -UseBasicParsing -Uri $endPointURL -Headers $headers)
            if ($Result.PSObject.Properties.Name -eq 'Value') {
                $Result.Value
            }
            else {
                $Result
            }
        }
        catch {
            Write-Host $_
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

Export-ModuleMember -Function Get-BcEnvironmentSessions
