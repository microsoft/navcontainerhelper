<#
 .Synopsis
  Convert HashTable (authContext) to GitHub-Go Credentials
 .Description
  Convert HashTable (authContext) to GitHub-Go Credentials
 .Example
  New-BcAuthContext -includeDeviceLogin | ConvertTo-GitHubGoCredentials | Set-Clipboard
#>
function ConvertTo-GitHubGoCredentials() {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [Hashtable] $bcAuthContext
    )
    if ($bcAuthContext.ContainsKey('ClientId') -and $bcAuthContext.ContainsKey('ClientSecret') -and $bcAuthContext.clientId -and $bcAuthContext.clientSecret) {
        @{ "ClientId" = $bcAuthContext.ClientId; "ClientSecret" = $bcAuthContext.ClientSecret } | ConvertTo-Json -Compress
    }
    elseif ($bcAuthContext.ContainsKey('RefreshToken') -and $bcAuthContext.RefreshToken) {
        @{ "RefreshToken" = $bcAuthContext.RefreshToken } | ConvertTo-Json -Compress
    }
    else {
        throw "BcAuthContext is wrongly formatted"
    }
}
Export-ModuleMember -Function ConvertTo-GitHubGoCredentials
