<# 
 .Synopsis
  Preview function for retrieving Bc Environments
 .Description
  Preview function for retrieving Bc Environments
#>
function Get-BcEnvironments {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }
    (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/applications/BusinessCentral/environments" -Headers $headers).Value
}
Export-ModuleMember -Function Get-BcEnvironments
