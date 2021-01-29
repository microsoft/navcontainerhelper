<# 
 .Synopsis
  Function for removing a Business Central online environment
 .Description
  Function for removing a Business Central online environment
  This function is a wrapper for https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api#delete-environment
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext.
 .Parameter applicationFamily
  Application Family in which the environment is located. Default is BusinessCentral.
 .Parameter environment
  Name of the environment to delete
 .Parameter doNotWait
  Include this switch if you don't want to wait for completion of the deletion
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  Remove-BcEnvironment -bcAuthContext $authContext -environment 'usSandbox'
#>
function Remove-BcEnvironment {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [switch] $doNotWait
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.name -eq $environment }
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
        Write-Host "Submitting environment removal request for $applicationFamily/$environment"
        try {
            Invoke-RestMethod -Method DELETE -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/applications/$applicationFamily/environments/$environment" -Headers $headers
        }
        catch {
            throw (GetExtenedErrorMessage $_.Exception)
        }
        Write-Host "Environment removal request submitted"
        if (!$doNotWait) {
            Write-Host -NoNewline "Removing."
            do {
                Start-Sleep -Seconds 2
                Write-Host -NoNewline "."
                $env = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.name -eq $environment }
            } while ($env -and $env.Status -eq "Removing")
            if ($env) {
                Write-Host -ForegroundColor Red $env.Status
                throw "Could not remove environment"
            }
            else {
                Write-Host -ForegroundColor Green "Removed"
            }
        }
    }
}
Export-ModuleMember -Function Remove-BcEnvironment
