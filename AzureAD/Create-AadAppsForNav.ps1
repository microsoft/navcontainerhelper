<# 
 .Synopsis
  Create Apps in Azure Active Directory to allow Single Signon when using AAD
 .Description
  This function will create an app in AAD, to allow Web and Windows Client to use AAD for authentication
  Optionally the function can also create apps for the Excel AddIn and/or PowerBI integration
 .Parameter AadAdminCredential
  Credentials for your AAD/Office 365 administrator user, who can create apps in the AAD
 .Parameter appIdUri
  Unique Uri to identify the AAD App (typically we use the URL for the Web Client)
 .Parameter publicWebBaseUrl
  URL for the Web Client (defaults to the value of appIdUri)
 .Parameter iconPath
  Path of the image you want to use for the SSO App
 .Parameter IncludeExcelAadApp
  Add this switch to request the function to also create an AAD app for the Excel AddIn
 .Parameter IncludePowerBiAadApp
  Add this switch to request the function to also create an AAD app for the PowerBI service
 .Parameter IncludeEMailAadApp
  Add this switch to request the function to also create an AAD app for the EMail service
 .Parameter IncludeApiAccess
  Add this switch to add application permissions for Web Services API and automation API
 .Parameter Singletenant
  Indicates whether this application is singletenant
 .Parameter PreAuthorizePowerShell
  Indicates whether the well known PowerShell AppID (1950a258-227b-4e31-a9cf-717495945fc2) should be pre-authorized for access
 .Parameter useCurrentAzureAdConnection
  Specify this switch to use the current Azure AD Connection instead of invoking Connect-AzureAD (which will pop up a UI)
 .Example
  Create-AadAppsForNAV -AadAdminCredential (Get-Credential) -appIdUri https://mycontainer.mydomain/bc/
#>
function Create-AadAppsForNav {
    Param (
        [Parameter(Mandatory=$false)]
        [PSCredential] $AadAdminCredential,
        [Parameter(Mandatory=$true)]
        [string] $appIdUri,
        [Parameter(Mandatory=$false)]
        [string] $publicWebBaseUrl = $appIdUri,
        [Parameter(Mandatory=$false)]
        [string] $iconPath,
        [switch] $IncludeExcelAadApp,
        [switch] $IncludePowerBiAadApp,
        [switch] $IncludeEmailAadApp,
        [switch] $IncludeApiAccess,
        [switch] $SingleTenant,
        [switch] $preAuthorizePowerShell,
        [switch] $useCurrentAzureAdConnection,
        [Hashtable] $bcAuthContext
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $publicWebBaseUrl = "$($publicWebBaseUrl.TrimEnd('/'))/"

    if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
        Write-Host "Installing NuGet Package Provider"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -WarningAction Ignore | Out-Null
    }

    if (!(Get-Package -Name AzureAD -ErrorAction Ignore)) {
        Write-Host "Installing AzureAD PowerShell package"
        Install-Package AzureAD -Force -WarningAction Ignore | Out-Null
    }

    # Connect to AzureAD
    if ($useCurrentAzureAdConnection) {
        $account = Get-AzureADCurrentSessionInfo
    }
    elseif ($bcAuthContext) {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $jwtToken = Parse-JWTtoken -token $bcAuthContext.accessToken
        if ($jwtToken.aud -ne 'https://graph.windows.net') {
            Write-Host -ForegroundColor Yellow "The accesstoken was provided for $($jwtToken.aud), should have been for https://graph.windows.net"
        }
        $account = Connect-AzureAD -AadAccessToken $bcAuthContext.accessToken -AccountId $jwtToken.upn
    }
    else {
        if ($AadAdminCredential) {
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AadAdminCredential.Password))
            if ($password.Length -gt 100) {
                $account = Connect-AzureAD -AadAccessToken $password -AccountId $AadAdminCredential.UserName
            }
            else {
                $account = Connect-AzureAD -Credential $AadAdminCredential
            }
        }
        else {
            $account = Connect-AzureAD
        }
    }

    $AdProperties = @{}
    $adUserObjectId = 0

    $aadDomain = $account.TenantDomain
    $aadTenant = $account.TenantId
    $AdProperties["AadTenant"] = $AadTenant

    if ($account.Account.Type -eq 'ServicePrincipal') {
        $adUser = Get-AzureADServicePrincipal -Filter "AppId eq '$($account.Account.Id)'"
    } else {
        $adUser = Get-AzureADUser -ObjectId $account.Account.Id
    }
    if (!$adUser) {
        throw "Could not identify Aad Tenant"
    }

    $adUserObjectId = $adUser.ObjectId
    
    # Remove "old" AD Application
    Get-AzureADMSApplication -All $true | Where-Object { $_.IdentifierUris.Contains($appIdUri) } | ForEach-Object { Remove-AzureADMSApplication -ObjectId $_.Id }

    $signInReplyUrls = @("$($publicWebBaseUrl.ToLowerInvariant())SignIn",$publicWebBaseUrl.ToLowerInvariant().TrimEnd('/'))
    $oAuthReplyUrls = @("$($publicWebBaseUrl.ToLowerInvariant())OAuthLanding.htm")
    if ($publicWebBaseUrl.ToUpperInvariant() -cne $publicWebBaseUrl) {
        $signInReplyUrls += @("$($publicWebBaseUrl)SignIn",$publicWebBaseUrl.TrimEnd('/'))
        $oAuthReplyUrls += @("$($publicWebBaseUrl)OAuthLanding.htm")
    }


    Write-Host "Creating AAD App for WebClient"
    if ($SingleTenant.IsPresent) {
        $signInAudience = 'AzureADMyOrg'
    }
    else {
        $signInAudience = 'AzureADMultipleOrgs'
    }

    $informationalUrl = @{
    }
    if ($iconPath) {
        $informationalUrl += @{ 
            "LogoUrl" = $iconPath
        }
    }

    $ssoAdApp = New-AzureADMSApplication `
        -DisplayName "WebClient for $publicWebBaseUrl" `
        -IdentifierUris $appIdUri `
        -Web @{ "RedirectUris" = $signInReplyUrls } `
        -SignInAudience $signInAudience `
        -InformationalUrl @{ "LogoUrl" = $iconPath } `
        -RequiredResourceAccess @(
            @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ResourceAccess = @(             # Microsoft Graph
                [PSCustomObject]@{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
                [PSCustomObject]@{ "Id" = "9769c687-087d-48ac-9cb3-c37dde652038"; "Type" = "Scope" }   # EWS.AccessAsUser.All
                [PSCustomObject]@{ "Id" = "5fa075e9-b951-4165-947b-c63396ff0a37"; "Type" = "Scope" }   # PrinterShare.ReadBasic.All
                [PSCustomObject]@{ "Id" = "21f0d9c0-9f13-48b3-94e0-b6b231c7d320"; "Type" = "Scope" }   # PrintJob.Create
                [PSCustomObject]@{ "Id" = "6a71a747-280f-4670-9ca0-a9cbf882b274"; "Type" = "Scope" }   # PrintJob.ReadBasic
            )}
            @{ ResourceAppId = "00000009-0000-0000-c000-000000000000"; ResourceAccess =                # Power BI Service
                [PSCustomObject]@{ "Id" = "4ae1bf56-f562-4747-b7bc-2fa0874ed46f"; "Type" = "Scope" }   # Report.Read.All
            }
            @{ ResourceAppId = "00000003-0000-0ff1-ce00-000000000000"; ResourceAccess = @(             # SharePoint
                [PSCustomObject]@{ "Id" = "640ddd16-e5b7-4d71-9690-3f4022699ee7"; "Type" = "Scope" }   # AllSites.Write
                [PSCustomObject]@{ "Id" = "2cfdc887-d7b4-4798-9b33-3d98d6b95dd2"; "Type" = "Scope" }   # MyFiles.Write
            )}
         )

    $admspwd = New-AzureADMSApplicationPassword -ObjectId $SsoAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
    $AdProperties["SsoAdAppKeyValue"] = $admspwd.SecretText

    $SsoAdAppId = $ssoAdApp.AppId.ToString()
    $AdProperties["SsoAdAppId"] = $SsoAdAppId

    # Get oauth2 permission id for sso app
    $oauth2permissionid = [GUID]::NewGuid().ToString()
    $ssoAdApp.Api.Oauth2PermissionScopes.Add(@{
        "Id" = $oauth2permissionid
        "value" = "user_impersonation"
        "Type" = "User"
        "adminConsentDisplayName" = "Access WebClient for $publicWebBaseUrl"
        "adminConsentDescription" = "Allow the application to access WebClient for $publicWebBaseUrl on behalf of the signed-in user."
        "userConsentDisplayName" = "Access WebClient for $publicWebBaseUrl"
        "userConsentDescription" = "Allow the application to access WebClient for $publicWebBaseUrl on your behalf."
        "IsEnabled" = $true
    })
    Set-AzureADMSApplication -ObjectId $ssoAdApp.Id -Api $ssoAdApp.Api

    if ($IncludeApiAccess) {
        $appRoleId = [Guid]::NewGuid().ToString()
        Set-AzureADMSApplication `
            -ObjectId $ssoAdApp.id `
            -AppRoles @{
                 "Id" = $appRoleId
                 "DisplayName" = "API.ReadWrite.All"
                 "Description" = "Full access to web services API"
                 "Value" = "API.ReadWrite.All"
                 "IsEnabled" = $true
                 "AllowedMemberTypes" = @("Application","User")
             }
    }

    if ($preAuthorizePowerShell) {
        $ssoAdApp.Api.PreAuthorizedApplications.Add(@{ "AppId" = "1950a258-227b-4e31-a9cf-717495945fc2"; "DelegatedPermissionIds" = @($oauth2permissionid) })
        Set-AzureADMSApplication -ObjectId $ssoAdApp.Id -Api $ssoAdApp.Api
    }

    # API Access Aad App
    if ($IncludeApiAccess) {
        # Remove "old" Api AAD Application
        $ApiIdentifierUri = $appIdUri.Replace('://','://api.')
        Get-AzureADMSApplication -All $true | Where-Object { $_.IdentifierUris.Contains($ApiIdentifierUri) } | ForEach-Object { Remove-AzureADMSApplication -ObjectId $_.Id }
    
        # Create AD Application
        Write-Host "Creating AAD App for API Access"
        $apiAdApp = New-AzureADMSApplication `
            -DisplayName "API Access for $publicWebBaseUrl" `
            -IdentifierUris $ApiIdentifierUri `
            -Web @{ "RedirectUris" = $oAuthReplyUrls } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess @(
                @{ ResourceAppId = "$SsoAdAppId"; ResourceAccess = @(                                      # BC SSO App
                    [PSCustomObject]@{ "Id" = "$oauth2permissionid";                  "Type" = "Scope" }   # OAuth2
                    [PSCustomObject]@{ "Id" = "$appRoleId";                           "Type" = "Role" }    # API.ReadWrite.All
                )}
                @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ResourceAccess =                # Microsoft Graph
                    [PSCustomObject]@{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
                }
             )
        
        $apiAdAppId = $apiAdApp.AppId.ToString()
        $AdProperties["ApiAdAppId"] = $apiAdAppId 
    
        $admspwd = New-AzureADMSApplicationPassword -ObjectId $apiAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["ApiAdAppKeyValue"] = $admspwd.SecretText

        $sp = @( $null, $null )
        $idx = 0
        $ssoAdAppId,$apiAdAppId | % {
            $appId = $_
            $app = Get-AzureADApplication -All $true | Where-Object { $_.AppId -eq $appId }
            if (!$app) {
                Write-Host -NoNewline "Waiting for AD App synchronization."
                do {
                    Start-Sleep -Seconds 2
                    $app = Get-AzureADApplication -All $true | Where-Object { $_.AppId -eq $appId }
                } while (!$app)
            }
            $sp[$idx] = Get-AzureADServicePrincipal -All $true | Where-Object { $_.AppId -eq $appId }
            if (!$sp[$idx]) {
                $sp[$idx] = New-AzureADServicePrincipal -AppId $appId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")
            }
            $idx++
        }
        New-AzureADServiceAppRoleAssignment -ObjectId $sp[1].ObjectId -PrincipalId $sp[1].ObjectId -ResourceId $sp[0].ObjectId -Id $appRoleId | Out-Null
    }

    # Excel Ad App
    if ($IncludeExcelAadApp) {
        # Remove "old" Excel AD Application
        $ExcelIdentifierUri = $appIdUri.Replace('://','://xls.')
        Get-AzureADMSApplication -All $true | Where-Object { $_.IdentifierUris.Contains($ExcelIdentifierUri) } | ForEach-Object { Remove-AzureADMSApplication -ObjectId $_.Id }

        # Create AD Application
        Write-Host "Creating AAD App for Excel Add-in"
        $excelAdApp = New-AzureADMSApplication `
            -DisplayName "Excel AddIn for $publicWebBaseUrl" `
            -IdentifierUris $ExcelIdentifierUri `
            -Web @{ "ImplicitGrantSettings" = @{ "EnableIdTokenIssuance" = $true; "EnableAccessTokenIssuance" = $true }; "RedirectUris" = ($oAuthReplyUrls+@("https://az689774.vo.msecnd.net/dynamicsofficeapp/v1.3.0.0/*")) } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess @(
                @{ ResourceAppId = "$SsoAdAppId"; ResourceAccess =                                         # BC SSO App
                    [PSCustomObject]@{ "Id" = "$oauth2permissionid";                  "Type" = "Scope" }   # Oauth2
                }
                @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ResourceAccess =                # Microsoft Graph
                    [PSCustomObject]@{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
                }
             )

        $ExcelAdAppId = $excelAdApp.AppId.ToString()
        $AdProperties["ExcelAdAppId"] = $ExcelAdAppId

        $admspwd = New-AzureADMSApplicationPassword -ObjectId $excelAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["ExcelAdAppKeyValue"] = $admspwd.SecretText
    }

    # PowerBI Ad App
    if ($IncludePowerBiAadApp) {
        # Remove "old" PowerBI AD Application
        $PowerBiIdentifierUri = $appIdUri.Replace('://','://pbi.')
        Get-AzureADMSApplication -All $true | Where-Object { $_.IdentifierUris.Contains($PowerBiIdentifierUri) } | ForEach-Object { Remove-AzureADMSApplication -ObjectId $_.Id }
    
        # Create AD Application
        Write-Host "Creating AAD App for PowerBI Service"
        $powerBiAdApp = New-AzureADMSApplication `
            -DisplayName "PowerBI Service for $publicWebBaseUrl" `
            -IdentifierUris $PowerBiIdentifierUri `
            -Web @{ "RedirectUris" = $oAuthReplyUrls } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess @(
                @{ ResourceAppId = "00000009-0000-0000-c000-000000000000"; ResourceAccess =                # Power BI Service
                    [PSCustomObject]@{ "Id" = "4ae1bf56-f562-4747-b7bc-2fa0874ed46f"; "Type" = "Scope" }   # Report.Read.All
                }
                @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ResourceAccess =                # Microsoft Graph
                    [PSCustomObject]@{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
                }
             )
          
        $PowerBiAdAppId = $powerBiAdApp.AppId.ToString()
        $AdProperties["PowerBiAdAppId"] = $PowerBiAdAppId 
    
        $admspwd = New-AzureADMSApplicationPassword -ObjectId $PowerBiAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["PowerBiAdAppKeyValue"] = $admspwd.SecretText
    }

    # EMail App
    if ($IncludeEmailAadApp) {
        # Remove "old" Email AD Application
        $EMailIdentifierUri = $appIdUri.Replace('://','://email.')
        Get-AzureADMSApplication -All $true | Where-Object { $_.IdentifierUris.Contains($EMailIdentifierUri) } | ForEach-Object { Remove-AzureADMSApplication -ObjectId $_.Id }
    
        # Create AD Application
        Write-Host "Creating AAD App for EMail Service"
        $EMailAdApp = New-AzureADMSApplication `
            -DisplayName "EMail Service for $publicWebBaseUrl" `
            -IdentifierUris $EMailIdentifierUri `
            -Web @{ "ImplicitGrantSettings" = @{ "EnableIdTokenIssuance" = $true; "EnableAccessTokenIssuance" = $true }; "RedirectUris" = $oAuthReplyUrls } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess `
                @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ResourceAccess = @(             # Microsoft Graph
                    [PSCustomObject]@{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
                    [PSCustomObject]@{ "Id" = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"; "Type" = "Scope" }   # Email
                    [PSCustomObject]@{ "Id" = "e383f46e-2787-4529-855e-0e479a3ffac0"; "Type" = "Scope" }   # Mail.ReadWrite
                    [PSCustomObject]@{ "Id" = "024d486e-b451-40bb-833d-3e66d98c5c73"; "Type" = "Scope" }   # Mail.Send
                )}
        
        $EMailAdAppId = $EMailAdApp.AppId.ToString()
        $AdProperties["EMailAdAppId"] = $EMailAdAppId 
    
        $admspwd = New-AzureADMSApplicationPassword -ObjectId $EmailAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["EMailAdAppKeyValue"] = $admspwd.SecretText
    }

    $AdProperties
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Create-AadAppsForBC -Value Create-AadAppsForNav
Export-ModuleMember -Function Create-AadAppsForNav -Alias Create-AadAppsForBC
