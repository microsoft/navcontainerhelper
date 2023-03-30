<#
 .Synopsis
  Function for renaming a Business Central online environment
 .Description
  Function for renaming a Business Central online environment
  Wrapper for https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments#rename-environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the old environment name
 .Parameter newEnvironmentName
  Name of the new environment name
 .Parameter apiVersion
  API version. Default is v2.15.
 .Parameter force
  Include this switch if you want to replace the destination environment
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the environment
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Rename-BcEnvironment -bcAuthContext $authContext -environment 'MySandbox' -newEnvironmentName "MySandbox2"
#>
function Rename-BcEnvironment {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [string] $newEnvironmentName,
        [string] $apiVersion = "v2.15",
        [switch] $force,
        [switch] $doNotWait
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        if (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.environmentName -in $environment, $newEnvironmentName) -and ($_.status -in "queued", "scheduled", "running") }) {
            Write-Host -NoNewline "Waiting for other environments."
            while (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.environmentName -in $environment, $newEnvironmentName) -and ($_.status -in "queued", "scheduled", "running") }) {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
            }
            Write-Host " done"
        }

        $bcEnvironments = Get-BcEnvironments -bcAuthContext $bcAuthContext
        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $environment }
        if (!($bcEnvironment)) {
            throw "No environment named $environment exists"
        }

        $bcEnvironment = $bcEnvironments | Where-Object { $_.name -eq $newEnvironmentName }
        if ($bcEnvironment -and !($force.IsPresent)) {
            throw "Environment named $newEnvironmentName exists"
        }
        if (($bcEnvironment) -and ($force.IsPresent)) {
            Remove-BcEnvironment -bcAuthContext $bcAuthContext -environment $newEnvironmentName
        }

        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{
            "Authorization" = $bearerAuthValue
        }
        $body = @{}
        "NewEnvironmentName" | % {
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
        if (($null -ne $environment) -and ($environment -ne "")) {
            $endPointURL += "/environments/$environment"
        }
        else {
            $endPointURL += "/environments"
        }
        $endPointURL += "/rename"

        Write-Host "Submitting rename environment request for $environment to $NewEnvironmentName"
        $body | ConvertTo-Json | Out-Host
        try {
            $environmentResult = (Invoke-RestMethod -Method POST -Uri $endPointURL -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json')
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Write-Host "Rename environment request submitted"
        if (!$doNotWait) {
            Write-Host -NoNewline "Renaming."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $Operation = (Get-BcEnvironmentsOperations -bcAuthContext $bcAuthContext | Where-Object { ($_.productFamily -eq $applicationFamily) -and ($_.type -eq $environmentResult.type) -and ($_.id -eq $environmentResult.id) })
            } while ($Operation.status -in "queued", "scheduled", "running")
            Write-Host $Operation.status
            if ($Operation.status -eq "failed") {
                throw "Could not rename environment with error: $($Operation.errorMessage)"
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

Export-ModuleMember -Function Rename-BcEnvironment
