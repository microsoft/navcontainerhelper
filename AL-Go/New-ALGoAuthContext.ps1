<# 
 .Synopsis
  Function for creating a mew AL-Go for GitHub compatible json representation of an AUTHCONTEXT
 .Description
  For many scenarios in AL-Go for GitHub, a AUTHCONTEXT secret is needed.
  This function converts a authContext hashtable obtained by New-BcAuthContext to a json string with the needed properties.
 .Parameter authContext
  Authorization Context obtained by New-BcAuthContext.
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  New-ALGoAuthContext -authContext $authContext | Set-Clipboard
 #>
 
 function New-ALGoAuthContext {
    Param(
        [Alias('bcAuthContext')]
        [HashTable] $authContext
    )

    $authContext = Renew-BcAuthContext $authContext

    if ($authContext.clientSecret) {
        $ht = @{
            "TenantID" = $authContext.TenantID
            "ClientID" = $authContext.ClientID
            "ClientSecret" = $authContext.ClientSecret
            "Scopes" = $authContext.Scopes
        }
    }
    else {
        $ht = @{
            "TenantID" = $authContext.TenantID
            "RefreshToken" = $authContext.RefreshToken
            "Scopes" = $authContext.Scopes
        }
    }
    $ht | ConvertTo-Json -Depth 99 -Compress
}
Set-Alias -Name Get-ALGoAuthContext -Value New-ALGoAuthContext
Export-ModuleMember -Function New-ALGoAuthContext -Alias Get-ALGoAuthContext
