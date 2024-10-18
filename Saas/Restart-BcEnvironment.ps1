<#
 .Synopsis
  Function for restarting a Business Central online environment
 .Description
  Function for restarting a Business Central online environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment for restarting
 .Parameter apiVersion
  API version. Default is v2.21.
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the environment
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Restart-BcEnvironment -bcAuthContext $authContext -environment 'MySandbox'
#>
function Restart-BcEnvironment {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $false)]
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $false)]
        [string] $apiversion = "v2.21",
        [Parameter(Mandatory = $false)]
        [switch] $doNotWait
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        Wait-BcEnvironmentsReady -environments @($environment) -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily

        $bcEnvironments = Get-BcEnvironments -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion
        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $environment }
        if (!($bcEnvironment)) {
            throw "No environment named $environment exists"
        }


        $bcAuthContext, $headers, $endPointURL = Create-SaasUrl -bcAuthContext $bcAuthContext -endPoint "restart" -environment $environment -applicationFamily $applicationFamily -apiVersion $apiVersion
           
        Write-Host "Submitting environment restart request for $environment"
        
        try {
            $environmentResult = (Invoke-RestMethod -Method POST -Uri $endPointURL -Headers $headers -ContentType 'application/json')
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "Restart environment request submitted"

        if (!$doNotWait) {
            Write-Host -NoNewline "Restarting."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
                $Operation = (Get-BcOperations -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.type -eq $environmentResult.type) -and ($_.id -eq $environmentResult.id) })
            } while ($Operation.status -in "queued", "scheduled", "running")
            Write-Host $Operation.status
            if ($Operation.status -eq "failed") {
                throw "Could not restart environment with error: $($Operation.errorMessage)"
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

Export-ModuleMember -Function Restart-BcEnvironment
