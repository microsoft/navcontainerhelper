function Get-UriAndHeadersForAlpaca {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $serviceUrl,
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext
    )

    $authContext = Renew-BcAuthContext $authContext
    $uri = "$($bcContainerHelperConfig.AlpacaSettings.BaseUrl.Trim('/'))/$($serviceUrl)?api-version=$($bcContainerHelperConfig.AlpacaSettings.ApiVersion)"
    $headers = @{
        'Authorization' = "Bearer $($authContext.AccessToken)"
        'Content-Type' = 'application/json'
    }
    $uri, $headers
}
