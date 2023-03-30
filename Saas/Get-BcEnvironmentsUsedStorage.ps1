<#
 .Synopsis
  Function for retrieving a list of used storage for all environments or one selected environment from an online Business Central tenant
 .Description
  Function for retrieving a list of used storage for all environments or one selected environment from an online Business Central tenant
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#get-used-storage-of-an-environment-by-application-family-and-name
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
  Get-BcEnvironmentsUsedStorage -bcAuthContext $authContext -environment "Sandbox"
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentsUsedStorage -bcAuthContext $authContext
#>
function Get-BcEnvironmentsUsedStorage {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = ('', 'BusinessCentral')[$PSBoundParameters.ContainsKey('environment')],
        [string] $environment = "",
        [string] $apiVersion = "v2.15"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        if (($null -eq $environment) -or ($environment -eq "")) {
            $applicationFamily = ''
        }

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }

        $endPointURL = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion"
        if (($null -ne $applicationFamily) -and ($applicationFamily -ne "")) {
            $endPointURL += "/applications/$applicationFamily"
        }
        if (($null -ne $environment) -and ($environment -ne "")) {
            $endPointURL += "/environments/$environment"
        }
        else {
            $endPointURL += "/environments"
        }
        $endPointURL += "/usedstorage"

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
Export-ModuleMember -Function Get-BcEnvironmentsUsedStorage
