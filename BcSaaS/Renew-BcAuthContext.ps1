<# 
 .Synopsis
  Function for refreshing a Business Central Authorization Context
 .Description
  Function for refreshing a Business Central Authorization Context
  If AccessToken is about to expire or has expired, refresh it
  If authentication was obtained using client_credentials flow, then Renew-BcAuthContext with authenticate using the same client credentials (ClientID+ClientSecret)
  If authentication was obtained using password, refresh_token or devicecode, then the refresh token in the auth context will be used to refresh the access token
 .Parameter bcAuthContext
  Authorization Context obtained by New-BcAuthContext.
 .Parameter minValidityPeriodInSeconds
  If the access token has a validity period lower than this number of seconds, trigger a refresh
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  # do a lot of work
  $authContext = Renew-BcAuthContext -bcAuthContext $authContext
  # do more work
#>
function Renew-BcAuthContext {
    Param(
        $bcAuthContext,
        [int] $minValidityPeriodInSeconds = 300
    )

    Test-BcAuthContext -bcAuthContext $bcAuthContext

    if ($bcAuthContext.UtcExpiresOn.Subtract([DateTime]::UtcNow).TotalSeconds -ge $minValidityPeriodInSeconds) {
        $bcAuthContext
    }
    else {
        New-BcAuthContext `
            -clientID $bcAuthContext.clientID `
            -Resource $bcAuthContext.Resource `
            -tenantID $bcAuthContext.tenantID `
            -authority $bcAuthContext.authority `
            -refreshToken $bcAuthContext.RefreshToken `
            -Scopes $bcAuthContext.Scopes `
            -clientSecret $bcAuthContext.clientSecret `
            -credential $bcAuthContext.Credential `
            -includeDeviceLogin:$bcAuthContext.includeDeviceLogin `
            -deviceLoginTimeout $bcAuthContext.deviceLoginTimeout
    }
}
Export-ModuleMember -Function Renew-BcAuthContext
