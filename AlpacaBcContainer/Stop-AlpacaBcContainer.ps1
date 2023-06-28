<#
 .SYNOPSIS
  Stops an Alpaca container.
 .DESCRIPTION
  Stops an Alpaca container.
  If the container is already stopped, nothing happens.
 .Parameter authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container id of the Alpaca Container to stop.
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  Stop-AlpacaBcContainer -authContext $authContext -containerId $containerId
#>
function Stop-AlpacaBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Service/$containerId/stop"
    (Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers) | Where-Object { $_ } | Out-Host
}
Export-ModuleMember -Function Stop-AlpacaBcContainer
