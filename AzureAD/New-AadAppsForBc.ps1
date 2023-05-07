<# 
 .Synopsis
  Create Apps in Azure Active Directory to allow Single Signon when using AAD
 .Description
  This function will create an app in AAD, to allow Web and Windows Client to use AAD for authentication
  Optionally the function can also create apps for the Excel AddIn and/or Other services integration
 .Parameter accessToken
  Accesstoken for Microsoft Graph with permissions to create apps in the AAD
 .Parameter appIdUri
  Unique Uri to identify the AAD App (typically we use the URL for the Web Client)
 .Parameter publicWebBaseUrl
  URL for the Web Client (defaults to the value of appIdUri)
 .Parameter iconPath
  Path of the image you want to use for the SSO App
 .Parameter IncludeExcelAadApp
  Add this switch to request the function to also create an AAD app for the Excel AddIn
 .Parameter IncludeOtherServicesAadApp
  Add this switch to request the function to also create an AAD app for other services (including PowerBI, SharePoint, Universal Print, etc.)
  https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/register-app-azure
 .Parameter IncludeApiAccess
  Add this switch to add application permissions for Web Services API and automation API
 .Parameter Singletenant
  Indicates whether this application is singletenant
 .Parameter PreAuthorizePowerShell
  Indicates whether the well known PowerShell AppID (1950a258-227b-4e31-a9cf-717495945fc2) should be pre-authorized for access
 .Parameter useCurrentMicrosoftGraphConnection
  Specify this switch to use the current Microsoft Graph Connection instead of invoking Connect-MgGraph (which will pop up a UI)
 .Example
  New-AadAppsForBC -accessToken $accessToken -appIdUri https://mycontainer.mydomain/bc/
 .Example
  $bcAuthContext = New-BcAuthContext -tenantID $azureTenantId -clientID $azureApplicationId -clientSecret $clientSecret -scopes "https://graph.microsoft.com/.default"
  $AdProperties = New-AadAppsForBc -appIdUri https://mycontainer.mydomain/bc/ -bcAuthContext $bcAuthContext 
#>
function New-AadAppsForBc {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $accessToken,
        [Parameter(Mandatory=$true)]
        [string] $appIdUri,
        [Parameter(Mandatory=$false)]
        [string] $publicWebBaseUrl = $appIdUri,
        [Parameter(Mandatory=$false)]
        [string] $iconPath,
        [switch] $IncludeExcelAadApp,
        [switch] $IncludeOtherServicesAadApp,
        [switch] $IncludeApiAccess,
        [switch] $SingleTenant,
        [switch] $preAuthorizePowerShell,
        [switch] $useCurrentMicrosoftGraphConnection,
        [Hashtable] $bcAuthContext
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $publicWebBaseUrl = "$($publicWebBaseUrl.TrimEnd('/'))/"

    if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
        Write-Host "Installing NuGet Package Provider"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -WarningAction Ignore | Out-Null
    }

    if (!(Get-Package -Name Microsoft.Graph -ErrorAction Ignore)) {
        Write-Host "Installing Microsoft.Graph PowerShell package"
        Install-Package Microsoft.Graph -Force -WarningAction Ignore | Out-Null
    }

    # Connect to Microsoft.Graph
    if (!$useCurrentMicrosoftGraphConnection) {
        if ($bcAuthContext) {
            $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
            $jwtToken = Parse-JWTtoken -token $bcAuthContext.accessToken
            if ($jwtToken.aud -ne 'https://graph.microsoft.com') {
                Write-Host -ForegroundColor Yellow "The accesstoken was provided for $($jwtToken.aud), should have been for https://graph.microsoft.com"
            }
            Connect-MgGraph -AccessToken $bcAuthContext.accessToken | Out-Null
        }
        else {
            if ($accessToken) {
                Connect-MgGraph -accessToken $accessToken | Out-Null
            }
            else {
                Connect-MgGraph -Scopes 'Application.ReadWrite.All' | Out-Null
            }
        }
    }
    $account = Get-MgContext

    $AdProperties = @{}

    $aadTenant = $account.TenantId
    $AdProperties["AadTenant"] = $AadTenant

    if ($null -eq $account.Account) {
        $adUser = Get-MgServicePrincipal -Filter "AppId eq '$($account.ClientId)'"
    } else {
        $adUser = Get-MgUser -UserId $account.Account
    }
    if (!$adUser) {
        throw "Could not identify Aad Tenant"
    }
    
    # Remove "old" AD Application
    Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $appIdUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

    $signInReplyUrls = @("$($publicWebBaseUrl.ToLowerInvariant())SignIn",$publicWebBaseUrl.ToLowerInvariant().TrimEnd('/'))
    $oAuthReplyUrls = @("$($publicWebBaseUrl.ToLowerInvariant())OAuthLanding.htm")
    if ($publicWebBaseUrl.ToLowerInvariant() -cne $publicWebBaseUrl) {
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
    $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants 
    $graphRRA.ResourceAccess = @(
        @{ Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; Type = "Scope" }   # User.Read
        @{ Id = "9769c687-087d-48ac-9cb3-c37dde652038"; Type = "Scope" }   # EWS.AccessAsUser.All
        @{ Id = "5fa075e9-b951-4165-947b-c63396ff0a37"; Type = "Scope" }   # PrinterShare.ReadBasic.All
        @{ Id = "21f0d9c0-9f13-48b3-94e0-b6b231c7d320"; Type = "Scope" }   # PrintJob.Create
        @{ Id = "6a71a747-280f-4670-9ca0-a9cbf882b274"; Type = "Scope" }   # PrintJob.ReadBasic
    )
    $powerBIRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    $powerBIRRA.ResourceAppId = "00000009-0000-0000-c000-000000000000" # Power BI Service
    $powerBIRRA.ResourceAccess = @(
        @{ "Id" = "4ae1bf56-f562-4747-b7bc-2fa0874ed46f"; "Type" = "Scope" }   # Report.Read.All
    )
    $sharepointRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    $sharepointRRA.ResourceAppId = "00000003-0000-0ff1-ce00-000000000000" # SharePoint
    $sharepointRRA.ResourceAccess = @(
        @{ "Id" = "640ddd16-e5b7-4d71-9690-3f4022699ee7"; "Type" = "Scope" }   # AllSites.Write
        @{ "Id" = "2cfdc887-d7b4-4798-9b33-3d98d6b95dd2"; "Type" = "Scope" }   # MyFiles.Write
    )
    $resourceAccessList = @($graphRRA, $powerBIRRA, $sharepointRRA)

    $ssoAdApp = New-MgApplication `
        -DisplayName "WebClient for $publicWebBaseUrl" `
        -IdentifierUris $appIdUri `
        -Web @{ ImplicitGrantSettings = @{ EnableIdTokenIssuance = $true }; RedirectUris = $signInReplyUrls } `
        -SignInAudience $signInAudience `
        -Info @{ "LogoUrl" = $iconPath } `
        -RequiredResourceAccess $resourceAccessList

    $admspwd = Add-MgApplicationPassword -ApplicationId $SsoAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
    $AdProperties["SsoAdAppKeyValue"] = $admspwd.SecretText

    $SsoAdAppId = $ssoAdApp.AppId.ToString()
    $AdProperties["SsoAdAppId"] = $SsoAdAppId

    # Get oauth2 permission id for sso app
    $oauth2permissionid = [GUID]::NewGuid().ToString()
    $oauth2PermissionScopes = $ssoAdApp.Api.Oauth2PermissionScopes
    $oauth2PermissionScopes +=  @{
        "Id" = $oauth2permissionid
        "value" = "user_impersonation"
        "Type" = "User"
        "adminConsentDisplayName" = "Access WebClient for $publicWebBaseUrl"
        "adminConsentDescription" = "Allow the application to access WebClient for $publicWebBaseUrl on behalf of the signed-in user."
        "userConsentDisplayName" = "Access WebClient for $publicWebBaseUrl"
        "userConsentDescription" = "Allow the application to access WebClient for $publicWebBaseUrl on your behalf."
        "IsEnabled" = $true
    }
    Update-MgApplication -ApplicationId $ssoAdApp.Id -Api @{Oauth2PermissionScopes = $oauth2PermissionScopes}

    if ($IncludeApiAccess) {
        $appRoleId = [Guid]::NewGuid().ToString()
        Update-MgApplication `
            -ApplicationId $ssoAdApp.id `
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
        $PreAuthorizedApplications = $ssoAdApp.Api.PreAuthorizedApplications
        $PreAuthorizedApplications += @{ "AppId" = "1950a258-227b-4e31-a9cf-717495945fc2"; "DelegatedPermissionIds" = @($oauth2permissionid) }
        Update-MgApplication -ApplicationId $ssoAdApp.Id -Api @{PreAuthorizedApplications = $PreAuthorizedApplications}
    }

    # API Access Aad App
    if ($IncludeApiAccess) {
        # Remove "old" Api AAD Application
        $ApiIdentifierUri = $appIdUri.Replace('://','://api.')
        Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $ApiIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }
    
        # Create AD Application
        Write-Host "Creating AAD App for API Access"
        $bcSSOAppRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $bcSSOAppRRA.ResourceAppId = "$SsoAdAppId"                                 # BC SSO App
        $bcSSOAppRRA.ResourceAccess = @(
            @{ "Id" = "$oauth2permissionid";                  "Type" = "Scope" }   # OAuth2
            @{ "Id" = "$appRoleId";                           "Type" = "Role" }    # API.ReadWrite.All
        )
        $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000"           # Microsoft Graph
        $graphRRA.ResourceAccess = @(
            @{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
        )
        $apiAppResourceAccessList = @($graphRRA, $bcSSOAppRRA)
        $apiAdApp = New-MgApplication `
            -DisplayName "API Access for $publicWebBaseUrl" `
            -IdentifierUris $ApiIdentifierUri `
            -Web @{ "RedirectUris" = $oAuthReplyUrls } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess $apiAppResourceAccessList
        
        $apiAdAppId = $apiAdApp.AppId.ToString()
        $AdProperties["ApiAdAppId"] = $apiAdAppId 
    
        $admspwd = Add-MgApplicationPassword -ApplicationId $apiAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["ApiAdAppKeyValue"] = $admspwd.SecretText

        $sp = @( $null, $null )
        $idx = 0
        $ssoAdAppId,$apiAdAppId | ForEach-Object {
            $appId = $_
            $app = Get-MgApplication -All | Where-Object { $_.AppId -eq $appId }
            if (!$app) {
                Write-Host -NoNewline "Waiting for AD App synchronization."
                do {
                    Start-Sleep -Seconds 2
                    $app = Get-MgApplication -All | Where-Object { $_.AppId -eq $appId }
                } while (!$app)
            }
            $sp[$idx] = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $appId }
            if (!$sp[$idx]) {
                $sp[$idx] = New-MgServicePrincipal -AppId $appId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")
            }
            $idx++
        }
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp[1].Id -PrincipalId $sp[1].Id -ResourceId $sp[0].Id -AppRoleId $appRoleId | Out-Null
    }

    # Excel Ad App
    if ($IncludeExcelAadApp) {
        # Remove "old" Excel AD Application
        $ExcelIdentifierUri = $appIdUri.Replace('://','://xls.')
        Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $ExcelIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

        # Create AD Application
        Write-Host "Creating AAD App for Excel Add-in"
        $bcSSOAppRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $bcSSOAppRRA.ResourceAppId = "$SsoAdAppId"                            # BC SSO App
        $bcSSOAppRRA.ResourceAccess = @(
            @{ "Id" = "$oauth2permissionid";                  "Type" = "Scope" }   # OAuth2
        )
        $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000"           # Microsoft Graph
        $graphRRA.ResourceAccess = @(
            @{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
        )
        $excelAppResourceAccessList = @($graphRRA, $bcSSOAppRRA)
        $excelAdApp = New-MgApplication `
            -DisplayName "Excel AddIn for $publicWebBaseUrl" `
            -IdentifierUris $ExcelIdentifierUri `
            -Spa @{ "RedirectUris" = ($oAuthReplyUrls+@("https://az689774.vo.msecnd.net/dynamicsofficeapp/v1.3.0.0/*")) } `
            -Web @{ "ImplicitGrantSettings" = @{ "EnableIdTokenIssuance" = $true; "EnableAccessTokenIssuance" = $true } } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess $excelAppResourceAccessList

        $ExcelAdAppId = $excelAdApp.AppId.ToString()
        $AdProperties["ExcelAdAppId"] = $ExcelAdAppId

        $admspwd = Add-MgApplicationPassword -ApplicationId $excelAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["ExcelAdAppKeyValue"] = $admspwd.SecretText
    }

    # Other Services Ad App
    if ($IncludeOtherServicesAadApp) {
        # Remove "old" Other Services AD Application
        $OtherServicesIdentifierUri = $appIdUri.Replace('://','://other.')
        Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $OtherServicesIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

        # Create AD Application
        Write-Host "Creating AAD App for Other Services"

        # Microsoft Graph
        $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000"           # Microsoft Graph
        $graphRRA.ResourceAccess = @(
            @{ "Id" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; "Type" = "Scope" }   # User.Read
            @{ "Id" = "5fa075e9-b951-4165-947b-c63396ff0a37"; "Type" = "Scope" }   # PrinterShare.ReadBasic.All
            @{ "Id" = "21f0d9c0-9f13-48b3-94e0-b6b231c7d320"; "Type" = "Scope" }   # PrintJob.Create
            @{ "Id" = "6a71a747-280f-4670-9ca0-a9cbf882b274"; "Type" = "Scope" }   # PrintJob.ReadBasic
            @{ "Id" = "9769c687-087d-48ac-9cb3-c37dde652038"; "Type" = "Scope" }   # EWS.AccessAsUser.All
            @{ "Id" = "d56682ec-c09e-4743-aaf4-1a3aac4caa21"; "Type" = "Scope" }   # Contacts.ReadWrite

        )

        $powerBIRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $powerBIRRA.ResourceAppId = "00000009-0000-0000-c000-000000000000"         # Power BI Service
        $powerBIRRA.ResourceAccess = @(
            @{ "Id" = "4ae1bf56-f562-4747-b7bc-2fa0874ed46f"; "Type" = "Scope" }   # Report.Read.All
            @{ "Id" = "b2f1b2fa-f35c-407c-979c-a858a808ba85"; "Type" = "Scope" }   # Workspace.Read.All
        )

        $sharePointRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
        $sharepointRRA.ResourceAppId = "00000003-0000-0ff1-ce00-000000000000"      # Sharepoint Service
        $sharepointRRA.ResourceAccess = @(
            @{ "Id" = "56680e0d-d2a3-4ae1-80d8-3c4f2100e3d0"; "Type" = "Scope" }   # AllSites.FullControl
            @{ "Id" = "82866913-39a9-4be7-8091-f4fa781088ae"; "Type" = "Scope" }   # User.ReadWrite.All
        )

        $otherServicesAppResourceAccessList = @($graphRRA, $powerBIRRA, $sharepointRRA)
        $otherServicesAdApp = New-MgApplication `
            -DisplayName "Other Services for $publicWebBaseUrl" `
            -IdentifierUris $OtherServicesIdentifierUri `
            -Web @{ "RedirectUris" = $oAuthReplyUrls } `
            -SignInAudience $signInAudience `
            -RequiredResourceAccess $otherServicesAppResourceAccessList
          
        $OtherServicesAdAppId = $otherServicesAdApp.AppId.ToString()
        $AdProperties["OtherServicesAdAppId"] = $OtherServicesAdAppId
    
        $admspwd = Add-MgApplicationPassword -ApplicationId $otherServicesAdApp.Id -PasswordCredential @{ "DisplayName" = "Password" }
        $AdProperties["OtherServicesAdAppKeyValue"] = $admspwd.SecretText
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
Export-ModuleMember -Function New-AadAppsForBc
