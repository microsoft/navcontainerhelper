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
  Resource used for OAuth2 flow. Default is https://api.businesscentral.dynamics.com/
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
 .Parameter credential
  If Credential is specified, the password flow will be included in the list of OAuth2 flows to try
 .Parameter includeDeviceLogin
  Include this switch if you want to include a device login prompt if no other way to authenticate succeeds
 .Parameter deviceLoginTimeout
  Timespan indicating the timeout while waiting for user to perform devicelogin. Default is 5 minutes.
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
        [string] $Resource = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/",
        [string] $tenantID = "Common",
        [string] $authority = "https://login.microsoftonline.com/$TenantID",
        [string] $refreshToken,
        [string] $scopes = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/.default",
        $clientSecret,
        [PSCredential] $credential,
        [switch] $includeDeviceLogin,
        [Timespan] $deviceLoginTimeout = [TimeSpan]::FromMinutes(5),
        [string] $deviceCode = ""
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if ($clientSecret -isnot [SecureString]) {
        $clientSecret = ConvertTo-SecureString -String "$clientSecret" -AsPlainText -Force
    }

    if ($deviceCode) {
        $includeDeviceLogin = $true
    }
    $authContext = @{
        "clientID"           = $clientID
        "Resource"           = $Resource
        "tenantID"           = $tenantID
        "authority"          = $authority
        "includeDeviceLogin" = $includeDeviceLogin
        "deviceLoginTimeout" = $deviceLoginTimeout
        "deviceCode"         = $deviceCode
    }
    $subject = "$($Resource.TrimEnd('/'))/$tenantID"
    $accessToken = $null
    if ($clientSecret) {
        $TokenRequestParams = @{
            Method = 'POST'
            Uri    = "$($authority.TrimEnd('/'))/oauth2/v2.0/token"
            Body   = @{
                "grant_type"    = "client_credentials"
                "scope"         = $scopes
                "client_id"     = $clientId
                "client_secret" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret))
            }
        }
        try {
            Write-Host "Attempting authentication to $scopes using clientCredentials..."
            $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
            $global:TT = $TokenRequest
            $accessToken = $TokenRequest.access_token
            $jwtToken = Parse-JWTtoken -token $accessToken
            Write-Host -ForegroundColor Green "Authenticated as app $($jwtToken.appid)"

            try {
                $expiresOn = [Datetime]::new(1970,1,1).AddSeconds($jwtToken.exp)
            }
            catch {
                $expiresOn = [DateTime]::now.AddSeconds($TokenRequest)
            }

            $authContext += @{
                "AccessToken"  = $accessToken
                "UtcExpiresOn" = $expiresOn
                "RefreshToken" = $null
                "Credential"   = $null
                "ClientSecret" = $clientSecret
                "scopes"       = $scopes
            }
            if ($tenantID -eq "Common") {
                Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)"
                $authContext.TenantId = $jwtToken.tid
            }

        }
        catch {
            $exception = $_.Exception
            Write-Host -ForegroundColor Red $exception.Message
            $accessToken = $null
        }
    }
    else {
        if ($credential) {
            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/token"
                Body   = @{
                    "grant_type" = "password"
                    "client_id"  = $ClientId
                    "username"   = $credential.UserName
                    "password"   = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password))
                    "resource"   = $Resource
                }
            }
            try {
                Write-Host "Attempting authentication to $subject using username/password..."
                $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                $accessToken = $TokenRequest.access_token
                $jwtToken = Parse-JWTtoken -token $accessToken
                Write-Host -ForegroundColor Green "Authenticated from $($jwtToken.ipaddr) as user $($jwtToken.name) ($($jwtToken.upn))"
    
                $authContext += @{
                    "AccessToken"  = $accessToken
                    "UtcExpiresOn" = [Datetime]::new(1970,1,1).AddSeconds($TokenRequest.expires_on)
                    "RefreshToken" = $TokenRequest.refresh_token
                    "Credential"   = $credential
                    "ClientSecret" = $null
                    "scopes"       = ""
                }
                if ($tenantID -eq "Common") {
                    Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)"
                    $authContext.TenantId = $jwtToken.tid
                }
            }
            catch {
                $exception = $_.Exception
                Write-Host -ForegroundColor Yellow $exception.Message.Replace('{EmailHidden}',$credential.UserName)
                $accessToken = $null
            }
        }
        if (!$accessToken -and $refreshToken) {
            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/token"
                Body   = @{
                    "grant_type"    = "refresh_token"
                    "client_id"     = $ClientId
                    "refresh_token" = $refreshToken
                }
            }
            try
            {
                Write-Host "Attempting authentication to $subject using refresh token..."
                $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                $accessToken = $TokenRequest.access_token
                try {
                    $jwtToken = Parse-JWTtoken -token $accessToken
                    Write-Host -ForegroundColor Green "Authenticated using refresh token as user $($jwtToken.name) ($($jwtToken.upn))"
                    $authContext += @{
                        "AccessToken"  = $accessToken
                        "UtcExpiresOn" = [Datetime]::new(1970,1,1).AddSeconds($TokenRequest.expires_on)
                        "RefreshToken" = $TokenRequest.refresh_token
                        "Credential"   = $null
                        "ClientSecret" = $null
                        "scopes"       = ""
                    }
                    if ($tenantID -eq "Common") {
                        Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)"
                        $authContext.TenantId = $jwtToken.tid
                    }
                }
                catch {
                    $accessToken = $null
                    throw "Invalid Access token"
                }
            }
            catch {
                Write-Host -ForegroundColor Yellow "Refresh token not valid"
            }
        }
        if (!$accessToken -and $includeDeviceLogin) {
            
            $deviceLoginStart = [DateTime]::Now
            $accessToken = ""
            $cnt = 0
    
            if ($deviceCode -eq "") {
                $DeviceCodeRequestParams = @{
                    Method = 'POST'
                    Uri    = "$($authority.TrimEnd('/'))/oauth2/devicecode"
                    Body   = @{
                        "client_id" = $ClientId
                        "resource"  = $Resource
                    }
                }
                
                Write-Host "Attempting authentication to $subject using device login..."
                $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams -UseBasicParsing
                Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow
                Write-Host -NoNewline "Waiting for authentication"
                $deviceCode = $DeviceCodeRequest.device_code
            }

            $TokenRequestParams = @{
                Method = 'POST'
                Uri    = "$($authority.TrimEnd('/'))/oauth2/token"
                Body   = @{
                    "grant_type" = "urn:ietf:params:oauth:grant-type:device_code"
                    "code"       = $deviceCode
                    "client_id"  = $ClientId
                }
            }

            while ($accessToken -eq "" -and ([DateTime]::Now.Subtract($deviceLoginStart) -lt $deviceLoginTimeout)) {
                Start-Sleep -Seconds 1
                try {
                    $TokenRequest = Invoke-RestMethod @TokenRequestParams -UseBasicParsing
                    $accessToken = $TokenRequest.access_token
                }
                catch {
                    $tokenRequest = $null
                    $exception = $_
                    try {
                        $err = ($exception.ErrorDetails.Message | ConvertFrom-Json).error
                        if ($err -eq "code_expired") {
                            Write-Host
                            Write-Host -ForegroundColor Red "Authentication request expired."
                            $deviceCode = ""
                        }
                        elseif ($err -eq "expired_token") {
                            Write-Host
                            Write-Host -ForegroundColor Red "Authentication token expired."
                            throw $exception
                        }
                        elseif ($err -eq "authorization_declined") {
                            Write-Host
                            Write-Host -ForegroundColor Red "Authentication request declined."
                            throw $exception
                        }
                        elseif ($err -eq "authorization_pending") {
                            if ($cnt++ % 5 -eq 0) {
                                Write-Host -NoNewline "."
                            }
                        }
                        else {
                            Write-Host
                            throw $exception
                        }
                    }
                    catch {
                        Write-Host 
                        throw $exception
                    }
                }
            }
            if ($accessToken) {
                try {
                    $jwtToken = Parse-JWTtoken -token $accessToken
                    Write-Host
                    Write-Host -ForegroundColor Green "Authenticated from $($jwtToken.ipaddr) as user $($jwtToken.name) ($($jwtToken.upn))"
                    $authContext += @{
                        "AccessToken"  = $accessToken
                        "UtcExpiresOn" = [Datetime]::new(1970,1,1).AddSeconds($TokenRequest.expires_on)
                        "RefreshToken" = $TokenRequest.refresh_token
                        "Credential"   = $null
                        "ClientSecret" = $null
                        "scopes"       = ""
                    }
                    if ($tenantID -eq "Common") {
                        Write-Host "Authenticated to common, using tenant id $($jwtToken.tid)"
                        $authContext.TenantId = $jwtToken.tid
                    }
                }
                catch {
                    $accessToken = $null
                    throw "Invalid Access token"
                }
            }
            else {
                $accessToken = "N/A"
                $authContext.deviceCode = $deviceCode
                $authContext += @{
                    "AccessToken"  = $accessToken
                    "UtcExpiresOn" = [Datetime]::Now
                    "RefreshToken" = ""
                    "Credential"   = $null
                    "ClientSecret" = $null
                    "scopes"       = ""
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
