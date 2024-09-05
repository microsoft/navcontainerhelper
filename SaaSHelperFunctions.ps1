function Create-SaasUrl {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,
        [string] $applicationFamily = "",
        [string] $environment = "",
        [string] $apiVersion = "",
        [string] $endPoint = ""
    )

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
    $headers = @{ "Authorization" = $bearerAuthValue }

    $endPointURL = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/admin/$apiVersion"
    if ($applicationFamily) {
        $endPointURL += "/applications/$applicationFamily"
    }
    if ($environment) {
        $endPointURL += "/environments/$environment"
    }
    else {
        $endPointURL += "/environments"
    }
    if ($endPoint) {
        $endPointURL += "/$endPoint"
    }

    return $bcAuthContext, $headers, $endPointURL
}
