﻿<#
 .Synopsis
  Function for retrieving Published AppSource Apps from an online Business Central environment
 .Description
  Function for retrieving Published AppSource Apps from an online Business Central environment
  Wrapper for https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api#get-installed-apps
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Environment from which you want to return the published Apps.
 .Parameter apiVersion
  API version. Default is v2.6.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentPublishedApps -bcAuthContext $authContext -environment "Sandbox"
#>
function Get-BcEnvironmentPublishedApps {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "v2.6"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }
        try {
            (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps" -Headers $headers).Value
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
Set-Alias -Name Get-BcPublishedApps -Value Get-BcEnvironmentPublishedApps
Export-ModuleMember -Function Get-BcEnvironmentPublishedApps -Alias Get-BcPublishedApps
