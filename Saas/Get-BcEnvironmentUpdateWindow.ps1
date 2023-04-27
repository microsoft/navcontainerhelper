<#
 .Synopsis
  Function for getting Update Window on a Business Central online environment
 .Description
  Function for getting Update Window on a Business Central online environment.
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment which you want to get the Update Window from
 .Parameter apiVersion
  API version. Default is v2.18.
 .Example
  $bcauthContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentUpdateWindow -bcAuthContext $bcAuthContext -environment "Sandbox"
#>
function Get-BcEnvironmentUpdateWindow {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "v2.18"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion -endPoint 'settings/upgrade'
        try {
            Invoke-RestMethod -Method Get -UseBasicParsing -Uri $endPointURL -Headers $headers
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
Export-ModuleMember -Function Get-BcEnvironmentUpdateWindow
