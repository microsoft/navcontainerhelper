<#
 .Synopsis
  Function for retrieving a list of operations for all environments or one selected environment from an online Business Central tenant
 .Description
  Function for retrieving a list of operations for all environments or one selected environment from an online Business Central tenant
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#get-environment-operations
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
  Get-BcEnvironmentOperations  -bcAuthContext $authContext
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentOperations  -bcAuthContext $authContext -environment "MySandbox"
#>
function Get-BcEnvironmentOperations {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = ('', 'BusinessCentral')[$PSBoundParameters.ContainsKey('environment')],
        [string] $environment = "",
        [string] $apiversion = "v2.19"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        if (($null -eq $environment) -or ($environment -eq "")) {
            $applicationFamily = ''
        }
        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "operations" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion
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
Set-Alias -Name Get-BcEnvironmentsOperations -Value Get-BcEnvironmentOperations
Set-Alias -Name Get-BcOperations -Value Get-BcEnvironmentOperations
Export-ModuleMember -Function Get-BcEnvironmentOperations -Alias Get-BcEnvironmentsOperations,Get-BcOperations
