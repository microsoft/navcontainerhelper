<#
 .Synopsis
  Function that wait for Business Central online environments when is ready.
 .Description
  Function that wait for Business Central online environments when is ready.
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environments
  Environments for which you want to check and wait for them.
 .Parameter apiVersion
  API version. Default is v2.15.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Wait-BcEnvironmentsReady -bcAuthContext $authContext -environment @("Sandbox","Production")
#>

function Wait-BcEnvironmentsReady {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string[]] $environments = @(),
        [string] $apiversion = "v2.19"
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        if (Get-BcOperations -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.environmentName -in $environments) -and ($_.status -in "queued", "scheduled", "running") }) {
            Write-Host -NoNewline "Waiting for environments $($environments -join(", ")) "
            while (Get-BcOperations -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.environmentName -in $environments) -and ($_.status -in "queued", "scheduled", "running") }) {
                $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
            }
            Write-Host " done"
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
Export-ModuleMember -Function Wait-BcEnvironmentsReady