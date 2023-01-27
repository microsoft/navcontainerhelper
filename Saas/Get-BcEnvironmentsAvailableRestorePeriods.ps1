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
  API version. Default is 2.15.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentsAvailableRestorePeriods -bcAuthContext $authContext -environment "MySandbox"
#>
function Get-BcEnvironmentsAvailableRestorePeriods {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory = $false)]
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "2.15"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }

        $endPointURL = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/v$apiVersion"
        if (($null -ne $applicationFamily) -and ($applicationFamily -ne "")) {
            $endPointURL += "/applications/$applicationFamily"
        }
        if (($null -ne $environment) -and ($environment -ne "")) {
            $endPointURL += "/environments/$environment"
        }
        else {
            $endPointURL += "/environments"
        }
        $endPointURL += "/availableRestorePeriods"

        try {
            $Result = (Invoke-RestMethod -Method Get -UseBasicParsing -Uri $endPointURL -Headers $headers)
            if ($null -ne $Result.Value) {
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
Export-ModuleMember -Function Get-BcEnvironmentsAvailableRestorePeriods
