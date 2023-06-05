<#
 .SYNOPSIS
  Removes an Alpaca container.
 .DESCRIPTION
  Removes an Alpaca container.
 .PARAMETER authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container id of the Alpaca Container to remove.
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  Remove-AlpacaBcContainer -authContext $authContext -containerId $containerId
#>
function Remove-AlpacaBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Service/$containerId"
    (Invoke-RestMethod -Method DELETE -Uri $uri -Headers $headers) | Where-Object { $_ } | Out-Host
}
Export-ModuleMember -Function Remove-AlpacaBcContainer
