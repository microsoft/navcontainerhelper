<#
 .SYNOPSIS
  Get information about one or more Alpaca BC Containers
 .DESCRIPTION
  Get information about one or more Alpaca BC Containers
 .PARAMETER authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container Id of the Alpaca container to get information about. If not provided, information about all containers is returned.
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  Get-AlpacaBcContainer -authContext $authContext | Format-Table
 .EXAMPLE
  $containerInfo = Get-AlpacaBcContainer -authContext $authContext -containerId $containerId
#>
function Get-AlpacaBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$false)]
        [string] $containerId = ''
    )

    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Service"
    if ($containerId) {
        (Invoke-RestMethod -Method GET -Uri $uri -Headers $headers) | Where-Object { $_.id -eq $containerId } | ForEach-Object { ConvertTo-HashTable -object $_ -recurse }
    }
    else {
        (Invoke-RestMethod -Method GET -Uri $uri -Headers $headers) | ForEach-Object { ConvertTo-HashTable -object $_ -recurse }
    }
}
Export-ModuleMember -Function Get-AlpacaBcContainer
