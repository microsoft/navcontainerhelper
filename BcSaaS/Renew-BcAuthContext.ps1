<# 
 .Synopsis
  Preview function for refreshing BC Auth Context
 .Description
  Preview function for refreshing BC Auth Context
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
