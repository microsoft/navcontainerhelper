<#
 .Synopsis
  Function for creating a Business Central online environment
 .Description
  Function for creating a Business Central online environment
  This function is a wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#create-new-environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the new environment
 .Parameter countryCode
  Country code of the new environment
 .Parameter environmentType
  Type of the new environment. Default is Sandbox.
 .Parameter ringName
  The logical ring group to create the environment within
 .Parameter applicationVersion
  The version of the application the environment should be created on
 .Parameter applicationInsightsKey
  Application Insights Key to add to the environment
 .Parameter apiVersion
  API version. Default is 2.3.
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the environment
 .Parameter getCompanyInfo
  Include this switch if you want to list the companies after creating the environment. Uses the Business Central Automation API.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  New-BcEnvironment -bcAuthContext $authContext -countryCode 'us' -environment 'usSandbox'
#>
function New-BcEnvironment {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [string] $countryCode,
        [ValidateSet('Sandbox', 'Production')]
        [string] $environmentType = "Sandbox",
        [string] $ringName = "PROD",
        [string] $applicationVersion = "",
        [string] $applicationInsightsKey = "",
        [string] $apiVersion = "v2.18",
        [switch] $doNotWait,
        [switch] $getCompanyInfo
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        Wait-BcEnvironmentsReady -environments @($environment) -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily

        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion -environment $environment

        $body = @{}
        "environmentType", "countryCode", "applicationVersion", "ringName" | % {
            $var = Get-Variable -Name $_ -ErrorAction SilentlyContinue
            if ($var -and $var.Value -ne "") {
                $body += @{
                    "$_" = $var.Value
                }
            }
        }

        Write-Host "Submitting new environment request for $applicationFamily/$environment"
        $body | ConvertTo-Json | Out-Host
        try {
            $environmentResult = (Invoke-RestMethod -Method PUT -Uri $endPointURL -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json')
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "New environment request submitted"
        if ($applicationInsightsKey) {
            Set-BcEnvironmentApplicationInsightsKey -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion -environment $environment -applicationInsightsKey $applicationInsightsKey
        }

        if (!$doNotWait) {
            Write-Host -NoNewline "Preparing."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
                $Operation = (Get-BcOperations -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.type -eq $environmentResult.type) -and ($_.id -eq $environmentResult.id) })
            } while ($Operation.status -in "queued", "scheduled", "running")
            Write-Host $Operation.status
            if ($Operation.status -eq "failed") {
                throw "Could not create environment with error: $($Operation.errorMessage)"
            }

            if ($getCompanyInfo.IsPresent) {
                $automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/automation/v2.0"
                try {
                    $companies = Invoke-RestMethod -Headers $headers -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
                }
                catch {
                    start-sleep -seconds 10
                    $companies = Invoke-RestMethod -Headers $headers -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
                }
                Write-Host "Companies in environment:"
                $companies.value | ForEach-Object { Write-Host "- $($_.name)" }
                $company = $companies.value | Select-Object -First 1
                $users = Invoke-RestMethod -Method Get -Uri "$automationApiUrl/companies($($company.Id))/users" -UseBasicParsing -Headers $headers
                Write-Host "Users in $($company.name):"
                $users.value | ForEach-Object { Write-Host "- $($_.DisplayName)" }
            }
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
Export-ModuleMember -Function New-BcEnvironment
