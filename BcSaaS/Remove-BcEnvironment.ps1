<# 
 .Synopsis
  Preview function for removing Bc Environments
 .Description
  Preview function for removing Bc Environments
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
                Write-Host $env.Status
            }
            else {
                Write-Host "Removed"
            }
            if ($status -ne "Active") {
                throw "Could not remove environment"
            }
        }
    }
}
Export-ModuleMember -Function Remove-BcEnvironment
