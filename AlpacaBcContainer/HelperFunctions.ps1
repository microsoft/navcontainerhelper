function isAlpacaBcContainer {
    Param(
        [Parameter(Mandatory=$false)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext = $null,
        [string] $containerId = ''
    )

    return ($authContext -ne $null) -and ($containerId) -and ($authContext.scopes.Split('/')[2] -eq $bcContainerHelperConfig.AlpacaSettings.OAuthHostName)
}

function Get-UriAndHeadersForAlpaca {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $serviceUrl,
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext
    )

    $authContext = Renew-BcAuthContext $authContext
    $uri = "$($bcContainerHelperConfig.AlpacaSettings.ApiBaseUrl.Trim('/'))/$($serviceUrl)?api-version=$($bcContainerHelperConfig.AlpacaSettings.ApiVersion)"
    $headers = @{
        'Authorization' = "Bearer $($authContext.AccessToken)"
        'Content-Type' = 'application/json'
    }
    $uri, $headers
}

function Get-WebClientUrlFromAlpacaBcContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

    $container = Get-AlpacaBcContainer -authContext $authContext -containerId $containerId
    $container.envs | Where-Object { $_ -like 'CustomNavSettings=*' } | ForEach-Object { $_.SubString('CustomNavSettings='.Length).Split(',') | Where-Object { $_ -like 'PublicWebBaseUrl=*' } | ForEach-Object { $_.SubString('PublicWebBaseUrl='.Length) } }
}