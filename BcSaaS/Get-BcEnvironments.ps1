<# 
 .Synopsis
  Preview function for retrieving Bc Environments
 .Description
  Preview function for retrieving Bc Environments
#>
function Get-BcEnvironments {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "BusinessCentral"
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }
    (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/applications/$applicationFamily/environments" -Headers $headers).Value
}
Export-ModuleMember -Function Get-BcEnvironments
