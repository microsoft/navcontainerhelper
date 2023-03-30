<#
 .Synopsis
  Function for removing a Business Central online environment
 .Description
  Function for removing a Business Central online environment
  This function is a wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#delete-environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment to delete
 .Parameter apiVersion
  API version. Default is v2.15.
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the deletion
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Remove-BcEnvironment -bcAuthContext $authContext -environment 'usSandbox'
#>
function Remove-BcEnvironment {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [string] $apiVersion = "v2.15",
        [switch] $doNotWait
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        Wait-BcEnvironmentReady -environments @($environment) -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -apiVersion $apiVersion | Where-Object { $_.name -eq $environment }
        if (!($bcEnvironment)) {
            throw "No environment named $environment exists"
        }
        if ($bcEnvironment.type -eq "Production") {
            throw "The BcContainerHelper Remove-BcEnvironment function cannot be used to remove Production environments"
        }
        else {

            $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
            $headers = @{
                "Authorization" = $bearerAuthValue
            }
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

            Write-Host "Submitting environment removal request for $applicationFamily/$environment"
            try {
                $environmentResult = (Invoke-RestMethod -Method DELETE -Uri $endPointURL -Headers $headers)
            }
            catch {
                throw (GetExtendedErrorMessage $_)
            }
            Write-Host "Environment removal request submitted"
            if (!$doNotWait) {
                Write-Host -NoNewline "Removing."
                do {
                    Start-Sleep -Seconds 2
                    Write-Host -NoNewline "."
                    $Operation = (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext -apiVersion $apiVersion -applicationFamily $applicationFamily | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.type -eq $environmentResult.type) -and ($_.id -eq $environmentResult.id) })
                } while ($Operation.status -in "queued", "scheduled", "running")
                Write-Host $Operation.status
                if ($Operation.status -eq "failed") {
                    throw "Could not remove environment with error: $($Operation.errorMessage)"
                }
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
Export-ModuleMember -Function Remove-BcEnvironment
