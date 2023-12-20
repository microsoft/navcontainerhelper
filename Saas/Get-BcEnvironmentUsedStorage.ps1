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
  Get-BcEnvironmentUsedStorage -bcAuthContext $authContext -environment "Sandbox"
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentUsedStorage -bcAuthContext $authContext
#>
function Get-BcEnvironmentUsedStorage {
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
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "usedstorage" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion
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
Set-Alias -Name Get-BcEnvironmentsUsedStorage -Value Get-BcEnvironmentUsedStorage
Set-Alias -Name Get-BcUsedStorage -Value Get-BcEnvironmentUsedStorage
Export-ModuleMember -Function Get-BcEnvironmentUsedStorage -Alias Get-BcEnvironmentsUsedStorage,Get-BcUsedStorage
