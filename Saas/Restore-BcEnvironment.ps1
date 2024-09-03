<#
 .Synopsis
  Function for restoring a Business Central online environment
 .Description
  Function for restoring a Business Central online environment
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#restore-environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter sourceEnvironment
  Name of the source environment
 .Parameter environment
  Name of the environment
 .Parameter environmentType
  Type of the new environment. Default is Sandbox.
 .Parameter pointInTime
  The point in time to which to restore the environment. Must be in ISO 8601 format in UTC ("2021-04-22T20:00:00Z")
 .Parameter apiVersion
  API version. Default is v2.15.
 .Parameter force
  Include this switch if you want to replace the destination environment
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the environment
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Restore-BcEnvironment -bcAuthContext $authContext -sourceEnvironment 'SrcMySandbox' -environment 'MySandbox' -pointInTime "2023-01-25T22:32:47Z"
#>
function Restore-BcEnvironment {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $sourceEnvironment,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [ValidateSet('Sandbox', 'Production')]
        [string] $environmentType = "Sandbox",
        [string] $pointInTime = "",
        [string] $apiversion = "v2.19",
        [switch] $force,
        [switch] $doNotWait
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        Wait-BcEnvironmentsReady -environments @($environment, $sourceEnvironment) -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bcEnvironments = Get-BcEnvironments -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $sourceEnvironment }
        if (!($bcEnvironment)) {
            throw "No environment named $sourceEnvironment exists"
        }

        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $environment }
        if ($bcEnvironment -and !($force.IsPresent)) {
            throw "Environment named $environment exists"
        }
        if (($bcEnvironment) -and ($force.IsPresent)) {
            Remove-BcEnvironment -bcAuthContext $bcAuthContext -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion
        }

        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "restore" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion

        $environmentName = $environment
        $body = @{}
        "environmentName", "environmentType", "pointInTime" | % {
            $var = Get-Variable -Name $_ -ErrorAction SilentlyContinue
            if ($var -and $var.Value -ne "") {
                $body += @{
                    "$_" = $var.Value
                }
            }
        }

        Write-Host "Submitting restore environment request for $applicationFamily/$environmentName from $applicationFamily/$sourceEnvironment"
        $body | ConvertTo-Json | Out-Host
        try {
            $environmentResult = (Invoke-RestMethod -Method POST -Uri $endPointURL -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json')
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "Restore environment request submitted"
        if (!$doNotWait) {
            Write-Host -NoNewline "Restoring."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
                $Operation = (Get-BcOperations -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.type -eq $environmentResult.type) -and ($_.id -eq $environmentResult.id) })
            } while ($Operation.status -in "queued", "scheduled", "running")
            Write-Host $Operation.status
            if ($Operation.status -eq "failed") {
                throw "Could not restore environment with error: $($Operation.errorMessage)"
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

Export-ModuleMember -Function Restore-BcEnvironment
