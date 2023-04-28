<# 
 .Synopsis
  Function for creating a mew AL-Go for GitHub compatible json representation of an AUTHCONTEXT
 .Description
  For many scenarios in AL-Go for GitHub, a AUTHCONTEXT secret is needed.
  This function converts a authContext hashtable obtained by New-BcAuthContext to a json string with the needed properties.
  The authContext can optionally also contain credentials for PowerPlatform authentication.
 .Parameter authContext
  Authorization Context obtained by New-BcAuthContext.
 .Parameter ppTenantId
  AAD TenantId for PowerPlatform (defaults to tenantId from AuthContext if provided)
 .Parameter ppApplicationId
  ApplicationId for PowerPlatform authentication (requires ppClientSecret)
 .Parameter ppClientSecret
  ClientSecret for PowerPlatform authentication (requires ppApplicationId)
 .Parameter ppUsername
  Username for PowerPlatform authentication (requires ppPassword)
 .Parameter ppPassword
  Password for PowerPlatform authentication (requires ppUsername)
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  New-ALGoAuthContext -authContext $authContext | Set-Clipboard
 .Example
  New-ALGoAuthContext -ppTenantId $ppTenantId -ppApplicationId $ppApplicationId -ppClientSecret $ppClientSecret | Set-Clipboard
 .Example
  New-ALGoAuthContext -authContext $authContext -ppUsername $ppUsername -ppPassword $ppPassword | Set-Clipboard
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin
  New-ALGoAuthContext -authContext $authContext -ppApplicationId $ppApplicationId -ppClientSecret $ppClientSecret | Set-Clipboard
 #>
 
function New-ALGoAuthContext {
    Param(
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [Alias('bcAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$false)]
        [string] $ppTenantId = '',
        [string] $ppApplicationId = '',
        [SecureString] $ppClientSecret = $null,
        [string] $ppUsername = '',
        [SecureString] $ppPassword = $null
    )

    $ht = @{}
    if ($authContext) {
        $authContext = Renew-BcAuthContext $authContext
    
        if ($authContext.clientSecret) {
            $ht = @{
                "TenantID" = $authContext.TenantID
                "ClientID" = $authContext.ClientID
                "ClientSecret" = $authContext.ClientSecret | Get-PlainText
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
    }
    if ($ppApplicationId) {
        if (-not $ppClientSecret) {
            throw "You need to specify ppClientSecret together with ppApplicationId"
        }
        if ($ppUsername -or $ppPassword) {
            throw "ppUsername/ppPassword shouldn't be specified together with ppApplicationId+ppClientSecret"
        }
        $ht += @{
            "ppApplicationId" = $ppApplicationId
            "ppClientSecret" = $ppClientSecret | Get-PlainText
        }
        if (-not $ppTenantId) {
            if ($authContext) {
                $ppTenantId = $authContext.tenantID
            }
            else {
                throw "You need to specify ppTenantId"
            }
        }
        $ht += @{
            "ppTenantId" = $ppTenantId
        }
    }
    elseif ($ppUsername) {
        if (-not $ppPassword) {
            throw "You need to specify ppPassword together with ppUsername"
        }
        if ($ppApplicationId -or $ppClientSecret) {
            throw "ppApplicationId/ppClientSecret shouldn't be specified together with ppUsername+ppPassword"
        }
        $ht += @{
            "ppUsername" = $ppUsername
            "ppPassword" = $ppPassword | Get-PlainText
        }
    }
    $algoauthcontext = $ht | ConvertTo-Json -Depth 99 -Compress
    if ($algoauthcontext -eq '{}') {
        throw "No valid authContext or PowerPlatform credentials provided"
    }
    $algoauthcontext
}
Set-Alias -Name Get-ALGoAuthContext -Value New-ALGoAuthContext
Export-ModuleMember -Function New-ALGoAuthContext -Alias Get-ALGoAuthContext
