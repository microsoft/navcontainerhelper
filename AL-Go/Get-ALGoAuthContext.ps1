<# 
 .Synopsis
  Function for getting an AL-Go for GitHub compatible json representation of an AUTHCONTEXT
 .Description
  For many scenarios in AL-Go for GitHub, a AUTHCONTEXT secret is needed.
  This function converts a bcAuthContext hashtable obtained by New-BcAuthContext to a json string with the needed properties.
 .Parameter bcAuthContext
  Authorization Context obtained by New-BcAuthContext.
 .Example
  $AuthContext = New-BcAuthContext -includeDeviceLogin
  Get-ALGoAuthContext -bcAuthContext $AuthContext | Set-Clipboard
 #>
 
 function Get-ALGoAuthContext {
    Param(
        $bcAuthContext
    )

    $bcAuthContext = Renew-BcAuthContext $bcAuthContext

    if ($bcAuthContext.clientSecret) {
        $ht = @{
            "TenantID" = $bcAuthContext.TenantID
            "ClientID" = $bcAuthContext.ClientID
            "ClientSecret" = $bcAuthContext.ClientSecret
        }
    }
    else {
        $ht = @{
            "TenantID" = $bcAuthContext.TenantID
            "RefreshToken" = $bcAuthContext.RefreshToken
        }
    }
    $ht | ConvertTo-Json -Compress
}
Export-ModuleMember -Function Get-ALGoAuthContext
