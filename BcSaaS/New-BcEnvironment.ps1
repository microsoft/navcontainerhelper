<# 
 .Synopsis
  Preview function for creating Bc Environments
 .Description
  Preview function for creating Bc Environments
#>
function New-BcEnvironment {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral",
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$true)]
        [string] $countryCode,
        [string] $environmentType = "Sandbox",
        [string] $ringName = "",
        [string] $applicationVersion = "",
        [string] $applicationInsightsKey = "",
        [switch] $doNotWait
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{
        "Authorization" = $bearerAuthValue
    }
    $body = @{}
    "environmentType","countryCode","applicationVersion","ringName" | % {
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
        Invoke-RestMethod -Method PUT -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/applications/$applicationFamily/environments/$environment" -Headers $headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json'
    }
    catch {
        throw (GetExtenedErrorMessage $_.Exception)
    }
    Write-Host "New environment request submitted"
    if (!$doNotWait) {
        Write-Host -NoNewline "Preparing."
        do {
            Start-Sleep -Seconds 2
            Write-Host -NoNewline "."
            $status = (Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.name -eq $environment }).status
        } while ($status -eq "Preparing")
        Write-Host $status
        if ($status -ne "Active") {
            throw "Could not create environment"
        }
    }
    if ($applicationInsightsKey) {
        Set-BcEnvironmentApplicationInsightsKey -bcAuthContext $bcAuthContext -applicationFamily $applicationFamily -environment $environment -applicationInsightsKey $applicationInsightsKey
    }
}
Export-ModuleMember -Function New-BcEnvironment
