<# 
 .Synopsis
  Function for creating a new Business Central Authorization Context
 .Description
  Function for creating a new Business Central Authorization Context
  The Authorization Context can be used to authenticate to a Business Central online tenant/environment in various function from ContainerHelper.
  The Authorization Context contains an AccessToken and you can renew the accesstoken (if necessary) by calling Renew-BcAuthContext
  Order of priority of OAuth2 flows: client_credentials, password, refresh_token, devicecode
 .Parameter clientID
  ClientID of AAD app to use for authentication. Default is a well known PowerShell AAD App ID (1950a258-227b-4e31-a9cf-717495945fc2)
 .Parameter Resource
  Resource used for OAuth2 flow. This parameter is obsolete, use scopes instead.
 .Parameter tenantID
  TenantID to use for OAuth2 flow. Default is Common
 .Parameter authority
  Authority to use for OAuth2 login. Default is https://login.microsoftonline.com/$TenantID
 .Parameter scopes
  Scopes to use for OAuth2 flow. Default is https://api.businesscentral.dynamics.com/.default
 .Parameter refreshToken
  If Refresh token is specified, the refresh_token flow will be included in the list of OAuth2 flows to try
 .Parameter clientSecret
  If ClientSecret is specified, the client_credentials flow will be included in the list of OAuth2 flows to try
 .Parameter clientAssertion
  If ClientAssertion is specified, the client_credentials flow (with ClientAssertion instead of ClientSecret) will be included in the list of OAuth2 flows to try
 .Parameter credential
  If Credential is specified, the password flow will be included in the list of OAuth2 flows to try
 .Parameter includeDeviceLogin
  Include this switch if you want to include a device login prompt if no other way to authenticate succeeds
 .Parameter authorizationCodeFlow
  Include this switch to use OAuth2 Authorization Code flow with PKCE and local redirect server
 .Parameter deviceLoginTimeout
  Timespan indicating the timeout while waiting for user to perform devicelogin. Default is 5 minutes.
 .Parameter deviceCode
  When deviceLogin expires, the deviceCode will be returned. You can use this to re-authenticate using the deviceCode and wait for the user to authenticate.
 .Parameter silent
  Include silent to avoid unnecessary output from the function
 .Example
  $authContext = New-BcAuthContext -refreshToken $refreshTokenSecret.SecretValueText
 .Example
  $authContext = New-BcAuthContext -clientID $clientID -clientSecret $clientSecret
 .Example
  $authContext = New-BcAuthContext -includeDeviceLogin -deviceLoginTimeout ([TimeSpan]::FromHours(1))
#>
function New-BcAuthContext {
    Param(
        [string] $clientID = "1950a258-227b-4e31-a9cf-717495945fc2",
        [string] $Resource = "",
        [string] $tenantID = "Common",
        [string] $authority = "https://login.microsoftonline.com/$TenantID",
        [string] $refreshToken,
        [string] $scopes = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/",
        $clientSecret,
        $clientAssertion,
        [PSCredential] $credential,
        [switch] $includeDeviceLogin,
        [switch] $authorizationCodeFlow,
        [Timespan] $deviceLoginTimeout = [TimeSpan]::FromMinutes(15),
        [string] $deviceCode = "",
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if ($clientSecret -and ($clientSecret -isnot [SecureString])) {
        $clientSecret = ConvertTo-SecureString -String "$clientSecret" -AsPlainText -Force
    }
    if ($clientAssertion -and ($clientAssertion -isnot [SecureString])) {
        $clientAssertion = ConvertTo-SecureString -String "$clientAssertion" -AsPlainText -Force
    }

    if ($deviceCode) {
        $includeDeviceLogin = $true
    }

    if ($authorizationCodeFlow) {
        # Authorization Code flow with PKCE is preferred over device login
        $includeDeviceLogin = $false
    }

    if ($resource) {
        Write-Host -ForegroundColor Yellow "Resource parameter on New-BcAuthContext is obsolete, please use scopes parameter instead"
        $scopes = "$($resource.TrimEnd('/'))/"
    }

    $authContext = @{
        "clientID"           = $clientID
        "scopes"             = $scopes
        "tenantID"           = $tenantID
        "authority"          = $authority
        "includeDeviceLogin" = $includeDeviceLogin
        "deviceLoginTimeout" = $deviceLoginTimeout
        "deviceCode"         = $deviceCode
    }
    $accessToken = $null
    if ($clientSecret -or $clientAssertion) {
        if ($scopes.EndsWith('/')) {
            $scopes += ".default"
        }

        $TokenRequestParams = @{
            Method = 'POST'
            Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/token"
            Body   = @{
                "grant_type"    = "client_credentials"
                "scope"         = $scopes
                "client_id"     = $clientId
            }
            Headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
        }
        if ($clientSecret) {
            $TokenRequestParams.Body += @{
                "client_secret" = ($clientSecret | Get-PlainText)
            }
        }
        else {
            $TokenRequestParams.Body += @{
                "client_assertion_type" = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                "client_assertion" = ($clientAssertion | Get-PlainText)
            }
        }
        try {
            if (!$silent) { Write-Host "Attempting authentication to $scopes using clientCredentials..." }
            $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
            $accessToken = $TokenRequest.access_token
            $jwtToken = Parse-JWTtoken -token $accessToken
            if (!$silent) { Write-Host -ForegroundColor Green "Authenticated as app $($jwtToken.appid)" }

            try {
                $expiresOn = [Datetime]::new(1970,1,1).AddSeconds($jwtToken.exp)
            }
            catch {
                $expiresOn = [DateTime]::now.AddSeconds($TokenRequest)
            }

            $authContext += @{
                "AccessToken"     = $accessToken
                "UtcExpiresOn"    = $expiresOn
                "RefreshToken"    = $null
                "Credential"      = $null
                "ClientSecret"    = $clientSecret
                "ClientAssertion" = $clientAssertion
                "appid"           = $jwtToken.appid
                "name"            = ""
                "upn"             = ""
        }
            if ($tenantID -eq "Common") {
                if (!$silent) { Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)" }
                $authContext.TenantId = $jwtToken.tid
            }

        }
        catch {
            Write-Host -ForegroundColor Red (GetExtendedErrorMessage $_)
            $accessToken = $null
        }
    }
    else {
        if ($scopes.EndsWith('/')) {
            $scopes += "user_impersonation offline_access"
        }

        if ($authorizationCodeFlow) {
            # Authorization Code flow with PKCE
            Add-Type -AssemblyName System.Web
            Add-Type -AssemblyName System.Net.Http

            # Generate PKCE parameters
            $codeVerifier = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $codeChallenge = [Convert]::ToBase64String([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::ASCII.GetBytes($codeVerifier))).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $state = [Guid]::NewGuid().ToString()
            
            # Start local HTTP listener
            $redirectUri = "http://localhost:38416/"
            $listener = New-Object System.Net.HttpListener
            $listener.Prefixes.Add($redirectUri)
            
            try {
                $listener.Start()
                if (!$silent) { Write-Host "Started local redirect server on $redirectUri" }
            }
            catch {
                Write-Host -ForegroundColor Red "Failed to start local server on port 38416. Port may be in use."
                throw $_
            }

            # Build authorization URL
            $authParams = @{
                "client_id"             = $clientID
                "response_type"         = "code"
                "redirect_uri"          = $redirectUri
                "scope"                 = $scopes
                "state"                 = $state
                "code_challenge"        = $codeChallenge
                "code_challenge_method" = "S256"
                "prompt"                = "select_account"
            }
            
            $authUrl = "$($authority.TrimEnd('/'))/oauth2/v2.0/authorize?" + (($authParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join '&')
            
            if (!$silent) { 
                Write-Host -ForegroundColor Yellow "Opening browser for authentication..."
                Write-Host -ForegroundColor Yellow "URL: $authUrl"
            }
            
            # Open browser
            Start-Process $authUrl
            
            # Wait for callback
            if (!$silent) { Write-Host "Waiting for authentication response..." }
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            # Send response to browser
            $responseHtml = "<html><body><h1>Authentication successful!</h1><p>You can close this window and return to PowerShell.</p></body></html>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
            $listener.Stop()
            
            # Parse query string
            $queryString = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
            $code = $queryString["code"]
            $returnedState = $queryString["state"]
            
            if ($returnedState -ne $state) {
                throw "State mismatch in OAuth2 flow"
            }
            
            if (!$code) {
                $error = $queryString["error"]
                $errorDescription = $queryString["error_description"]
                throw "Authorization failed: $error - $errorDescription"
            }
            
            # Exchange code for token
            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/token"
                Body   = @{
                    "grant_type"    = "authorization_code"
                    "client_id"     = $ClientId
                    "code"          = $code
                    "redirect_uri"  = $redirectUri
                    "code_verifier" = $codeVerifier
                    "scope"         = $scopes
                }
                Headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
            }
            
            try {
                if (!$silent) { Write-Host "Exchanging authorization code for access token..." }
                $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                $accessToken = $TokenRequest.access_token
                $jwtToken = Parse-JWTtoken -token $accessToken
                if (!$silent) { Write-Host -ForegroundColor Green "Authenticated from $($jwtToken.ipaddr) as user $($jwtToken.name) ($($jwtToken.unique_name))" }
                $authContext += @{
                    "AccessToken"     = $accessToken
                    "UtcExpiresOn"    = [Datetime]::UtcNow.AddSeconds($TokenRequest.expires_in)
                    "RefreshToken"    = $null
                    "Credential"      = $null
                    "ClientSecret"    = $null
                    "ClientAssertion" = $null
                    "appid"           = ""
                    "name"            = $jwtToken.name
                    "upn"             = $jwtToken.unique_name
                }
                if ($TokenRequest.PSObject.Properties.Name -eq 'refresh_token') {
                    $authContext.RefreshToken = $TokenRequest.refresh_token
                }
                if ($tenantID -eq "Common") {
                    if (!$silent) { Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)" }
                    $authContext.TenantId = $jwtToken.tid
                }
            }
            catch {
                Write-Host -ForegroundColor Red (GetExtendedErrorMessage $_)
                $accessToken = $null
            }
        }

        if (!$accessToken -and $credential) {
            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/token"
                Body   = @{
                    "grant_type" = "password"
                    "client_id"  = $ClientId
                    "username"   = $credential.UserName
                    "password"   = ($credential.Password | Get-PlainText)
                    "scope"      = $scopes
                }
                Headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
            }
            try {
                if (!$silent) { Write-Host "Attempting authentication to $Scopes using username/password..." }
                $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                $accessToken = $TokenRequest.access_token
                $jwtToken = Parse-JWTtoken -token $accessToken
                if (!$silent) { Write-Host -ForegroundColor Green "Authenticated from $($jwtToken.ipaddr) as user $($jwtToken.name) ($($jwtToken.unique_name))" }
                $authContext += @{
                    "AccessToken"     = $accessToken
                    "UtcExpiresOn"    = [Datetime]::UtcNow.AddSeconds($TokenRequest.expires_in)
                    "RefreshToken"    = $null
                    "Credential"      = $credential
                    "ClientSecret"    = $null
                    "ClientAssertion" = $null
                    "appid"           = ""
                    "name"            = $jwtToken.name
                    "upn"             = $jwtToken.unique_name
                }
                if ($TokenRequest.PSObject.Properties.Name -eq 'refresh_token') {
                    $authContext.RefreshToken = $TokenRequest.refresh_token
                }
                if ($tenantID -eq "Common") {
                    if (!$silent) { Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)" }
                    $authContext.TenantId = $jwtToken.tid
                }
            }
            catch {
                Write-Host -ForegroundColor Yellow (GetExtendedErrorMessage $_).Replace('{EmailHidden}',$credential.UserName)
                $accessToken = $null
            }
        }
        if (!$accessToken -and $refreshToken) {
            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/token"
                Body   = @{
                    "grant_type"    = "refresh_token"
                    "client_id"     = $ClientId
                    "refresh_token" = $refreshToken
                    "scope"         = $scopes
                }
                Headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
            }
            try
            {
                if (!$silent) { Write-Host "Attempting authentication to $Scopes using refresh token..." }
                $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                $accessToken = $TokenRequest.access_token
                try {
                    $jwtToken = Parse-JWTtoken -token $accessToken
                    if (!$silent) { Write-Host -ForegroundColor Green "Authenticated using refresh token as user $($jwtToken.name) ($($jwtToken.unique_name))" }
                }
                catch {
                    $accessToken = $null
                    throw "Invalid Access token"
                }
                $authContext += @{
                    "AccessToken"     = $accessToken
                    "UtcExpiresOn"    = [Datetime]::UtcNow.AddSeconds($TokenRequest.expires_in)
                    "RefreshToken"    = $TokenRequest.refresh_token
                    "Credential"      = $null
                    "ClientSecret"    = $null
                    "ClientAssertion" = $null
                    "appid"           = ""
                    "name"            = $jwtToken.name
                    "upn"             = $jwtToken.unique_name
                    }
                if ($tenantID -eq "Common") {
                    if (!$silent) { Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)" }
                    $authContext.TenantId = $jwtToken.tid
                }
            }
            catch {
                Write-Host -ForegroundColor Yellow "Refresh token not valid"
            }
        }
        if (!$accessToken -and $includeDeviceLogin) {
            
            $deviceLoginStart = [DateTime]::Now
            $accessToken = ""
            $userCode = ""
            $message = ""
            $interval = 5
    
            if ($deviceCode -eq "") {
                $DeviceCodeRequestParams = @{
                    Method = 'POST'
                    Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/devicecode"
                    Body   = @{
                        "client_id" = $ClientId
                        "scope"     = $Scopes
                    }
                    Headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
                }
                
                Write-Host "Attempting authentication to $Scopes using device login..."
                $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams -UseBasicParsing
                Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow
                $deviceCode = $DeviceCodeRequest.device_code
                $userCode = $DeviceCodeRequest.user_code
                $interval = $DeviceCodeRequest.interval
                $message = $DeviceCodeRequest.message
                Write-Host -NoNewline "Waiting for authentication (interval=$interval)"
            }

            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/token"
                Body   = @{
                    "grant_type"  = "urn:ietf:params:oauth:grant-type:device_code"
                    "device_code" = $deviceCode
                    "client_id"   = $ClientId
                }
                Headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
            }

            while ($accessToken -eq "" -and ([DateTime]::Now.Subtract($deviceLoginStart) -lt $deviceLoginTimeout)) {
                Start-Sleep -Seconds $interval
                try {
                    $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                    $accessToken = $TokenRequest.access_token
                }
                catch {
                    $tokenRequest = $null
                    $errorRecord = $_
                    try {
                        $err = ($errorRecord.ErrorDetails.Message | ConvertFrom-Json).error
                        if ($err -eq "code_expired") {
                            Write-Host
                            Write-Host -ForegroundColor Red "Authentication request expired."
                            $deviceCode = ""
                        }
                        elseif ($err -eq "expired_token") {
                            Write-Host
                            Write-Host -ForegroundColor Red "Authentication token expired!"
                            $errorRecord = "Authentication token expired!"
                            throw $errorRecord
                        }
                        elseif ($err -eq "authorization_declined") {
                            Write-Host
                            Write-Host -ForegroundColor Red "Authentication request declined!"
                            $errorRecord = "Authentication request declined!"
                            throw $errorRecord
                        }
                        elseif ($err -eq "authorization_pending") {
                            Write-Host -NoNewline "."
                        }
                        else {
                            Write-Host
                            throw $errorRecord
                        }
                    }
                    catch {
                        Write-Host 
                        throw $errorRecord
                    }
                }
            }
            if ($accessToken) {
                try {
                    $jwtToken = Parse-JWTtoken -token $accessToken
                    Write-Host
                    Write-Host -ForegroundColor Green "Authenticated from $($jwtToken.ipaddr) as user $($jwtToken.name) ($($jwtToken.unique_name))"
                }
                catch {
                    $accessToken = $null
                    throw "Invalid Access token"
                }
                $authContext += @{
                    "AccessToken"     = $accessToken
                    "UtcExpiresOn"    = [Datetime]::UtcNow.AddSeconds($TokenRequest.expires_in)
                    "RefreshToken"    = $null
                    "Credential"      = $null
                    "ClientSecret"    = $null
                    "ClientAssertion" = $null
                    "appid"           = ""
                    "name"            = $jwtToken.name
                    "upn"             = $jwtToken.unique_name
                }
                if ($TokenRequest.PSObject.Properties.Name -eq 'refresh_token') {
                    $authContext.RefreshToken = $TokenRequest.refresh_token
                }
                if ($tenantID -eq "Common") {
                    Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)"
                    $authContext.TenantId = $jwtToken.tid
                }
            }
            else {
                Write-Host
                $accessToken = "N/A"
                $authContext.deviceCode = $deviceCode
                $authContext += @{
                    "AccessToken"     = $accessToken
                    "UtcExpiresOn"    = [Datetime]::Now
                    "RefreshToken"    = ""
                    "Credential"      = $null
                    "ClientSecret"    = $null
                    "ClientAssertion" = $null
                    "appid"           = ""
                    "name"            = ""
                    "upn"             = ""
                    "userCode"        = $userCode
                    "message"         = $message
                }
            }
        }
    }
    if (!$accessToken) {
        Write-Host
        Write-Host -ForegroundColor Yellow "Authentication failed"
        return $null
    }
    return $authContext
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function New-BcAuthContext
