﻿<#
 .Synopsis
  Function for retrieving Database Export History from an online Business Central environment
 .Description
  Function for retrieving Database Export History from an online Business Central environment
  Wrapper for https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api#get-export-history
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Environment from which you want to return the published Apps.
 .Parameter apiVersion
  API version. Default is v2.1.
 .Parameter startTime
  start time for the query (get export history from this time)
 .Parameter endTime
  end time for the query (get export history until this time)
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Get-BcEnvironmentDatabaseExportHistory -bcAuthContext $authContext
#>
function Get-BcEnvironmentDatabaseExportHistory {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [string] $environment = "*",
        [string] $apiVersion = "v2.1",
        [DateTime] $startTime = (Get-Date).AddDays(-1),
        [DateTime] $endTime = (Get-Date).AddDays(1)
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }
        try {
            (Invoke-RestMethod -Method Get -Uri "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion/exports/history?start=$startTime&end=$endTime" -Headers $headers).value | Where-Object { $_.environmentName -like $environment }
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
Set-Alias -Name Get-BcDatabaseExportHistory -Value Get-BcEnvironmentDatabaseExportHistory
Export-ModuleMember -Function Get-BcEnvironmentDatabaseExportHistory -Alias Get-BcDatabaseExportHistory
