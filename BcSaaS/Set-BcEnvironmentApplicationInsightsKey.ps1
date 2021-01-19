<# 
 .Synopsis
  Preview function for setting Bc Environment Application Insights Key
 .Description
  Preview function for setting Bc Environment Application Insights Key
#>
function Set-BcEnvironmentApplicationInsightsKey {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [string] $applicationInsightsKey = "",
        [switch] $doNotWait
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{
        "Authorization" = $bearerAuthValue
    }
    $body = @{
        "key" = $applicationInsightsKey
    }
    Write-Host "Submitting new Application Insights Key for $applicationFamily/$environment"
    $body | ConvertTo-Json | Out-Host
    try {
        Invoke-RestMethod -Method POST -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/applications/$applicationFamily/environments/$environment/settings/appInsightsKey" -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json'
    }
    catch {
        throw (GetExtenedErrorMessage $_.Exception)
    }
    Write-Host "New Application Insights Key submitted"
    if (!$doNotWait) {
        Write-Host -NoNewline "Restarting."
        do {
            Start-Sleep -Seconds 2
            Write-Host -NoNewline "."
            $status = (Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.name -eq $environment }).status
        } while ($status -eq "Restarting")
        Write-Host $status
        if ($status -ne "Active") {
            throw "Could not create environment"
        }
    }
}
Export-ModuleMember -Function Set-BcEnvironmentApplicationInsightsKey
