<# 
 .Synopsis
  Preview function for retrieving Bc Published Apps from Environment
 .Description
  Preview function for retrieving Bc Published Apps from Environment
#>
function Get-BcPublishedApps {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }
    (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "https://api.businesscentral.dynamics.com/admin/v2.3/applications/BusinessCentral/environments/$environment/apps" -Headers $headers).Value
}
Export-ModuleMember -Function Get-BcPublishedApps
