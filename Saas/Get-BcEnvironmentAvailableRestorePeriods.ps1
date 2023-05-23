<#
 .Synopsis
  Function for retrieving a list of available restore periods for one selected environment from an online Business Central tenant
 .Description
  Function for retrieving a list of available restore periods for one selected environment from an online Business Central tenant
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#get-available-restore-periods
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment
 .Parameter apiVersion
  API version. Default is v2.15.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentAvailableRestorePeriods -bcAuthContext $authContext -environment "MySandbox"
#>
function Get-BcEnvironmentAvailableRestorePeriods {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory = $false)]
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment = "",
        [string] $apiVersion = "v2.15"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "availableRestorePeriods" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion
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
Set-Alias -Name Get-BcEnvironmentsAvailableRestorePeriods -Value Get-BcEnvironmentAvailableRestorePeriods
Set-Alias -Name Get-BcAvailableRestorePeriods -Value Get-BcEnvironmentAvailableRestorePeriods
Export-ModuleMember -Function Get-BcEnvironmentAvailableRestorePeriods -Alias Get-BcEnvironmentsAvailableRestorePeriods,Get-BcAvailableRestorePeriods

