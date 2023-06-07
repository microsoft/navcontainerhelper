<#
 .SYNOPSIS
  Starts an Alpaca container.
 .DESCRIPTION
  Starts an Alpaca container.
  If the container is already started, it is restarted.
 .Parameter authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container id of the Alpaca Container to start.
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  Start-AlpacaBcContainer -authContext $authContext -containerId $containerId
 .EXAMPLE
  Start-AlpacaBcContainer -authContext $authContext -containerId $containerId -doNotWait
#>
function Start-AlpacaBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [switch] $doNotWait
    )

    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Service/$containerId/start"
    (Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers) | Where-Object { $_ } | Out-Host
    if (!$doNotWait) {
        Wait-AlpacaBcContainerReady -authContext $authContext -containerId $containerId
    }
}
Export-ModuleMember -Function Start-AlpacaBcContainer
