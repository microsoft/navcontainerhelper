<#
 .Synopsis
  Function for copying a Business Central online environment
 .Description
  Function for copying a Business Central online environment
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#copy-environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the new environment
 .Parameter sourceEnvironment
  Name of the source environment
 .Parameter environmentType
  Type of the new environment. Default is Sandbox.
 .Parameter applicationInsightsKey
  Application Insights Key to add/replace to the environment
 .Parameter apiVersion
  API version. Default is v2.15.
 .Parameter force
  Include this switch if you want to replace the destination environment
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the environment
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Copy-BcEnvironment -bcAuthContext $authContext -environment 'NewSandbox' -sourceEnvironment "CopiedSandbox"
#>
function Copy-BcEnvironment {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [string] $sourceEnvironment,
        [ValidateSet('Sandbox', 'Production')]
        [string] $environmentType = "Sandbox",
        [string] $applicationInsightsKey = "",
        [string] $apiVersion = "v2.15",
        [switch] $force,
        [switch] $doNotWait
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        if (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.environmentName -in $environment, $sourceEnvironment) -and ($_.status -in "queued", "scheduled", "running") }) {
            Write-Host -NoNewline "Waiting for environments."
            while (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.environmentName -in $environment, $sourceEnvironment) -and ($_.status -in "queued", "scheduled", "running") }) {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
            }
            Write-Host " done"
        }

        $bcEnvironments = Get-BcEnvironments -bcAuthContext $bcAuthContext
        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $sourceEnvironment }
        if (!($bcEnvironment)) {
            throw "No environment named $sourceEnvironment exists"
        }

        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $environment }
        if ($bcEnvironment -and !($force.IsPresent)) {
            throw "Environment named $environment exists"
        }
        if (($bcEnvironment) -and ($force.IsPresent)) {
            Remove-BcEnvironment -bcAuthContext $bcAuthContext -environment $environment
        }


        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{
            "Authorization" = $bearerAuthValue
        }
        $type = $environmentType
        $environmentName = $environment
        $body = @{}
        "environmentName", "type" | % {
            $var = Get-Variable -Name $_ -ErrorAction SilentlyContinue
            if ($var -and $var.Value -ne "") {
                $body += @{
                    "$_" = $var.Value
                }
            }
        }

        $endPointURL = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion"
        if (($null -ne $applicationFamily) -and ($applicationFamily -ne "")) {
            $endPointURL += "/applications/$applicationFamily"
        }
        if (($null -ne $sourceEnvironment) -and ($sourceEnvironment -ne "")) {
            $endPointURL += "/environments/$sourceEnvironment"
        }
        else {
            $endPointURL += "/environments"
        }
        $endPointURL += "/copy"

        Write-Host "Submitting copy environment request for $applicationFamily/$sourceEnvironment to $applicationFamily/$environmentName"
        $body | ConvertTo-Json | Out-Host
        try {
            $environmentResult = (Invoke-RestMethod -Method POST -Uri $endPointURL -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json')
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "Copy environment request submitted"

        if (!$doNotWait) {
            Write-Host -NoNewline "Copying."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $Operation = (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.type -eq $environmentResult.type) -and ($_.id -eq $environmentResult.id) })
            } while ($Operation.status -in "queued", "scheduled", "running")
            Write-Host $Operation.status
            if ($Operation.status -eq "failed") {
                throw "Could not create environment with error: $($Operation.errorMessage)"
            }
        }
        if ($applicationInsightsKey) {
            Set-BcEnvironmentApplicationInsightsKey -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -environment $environment -applicationInsightsKey $applicationInsightsKey
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

Export-ModuleMember -Function Copy-BcEnvironment
