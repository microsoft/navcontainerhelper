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

    function Create-AesKey {
        $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
        $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
        $aesManaged.BlockSize = 128
        $aesManaged.KeySize = 256
        $aesManaged.GenerateKey()
        [System.Convert]::ToBase64String($aesManaged.Key)
    }
    
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
    Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris -contains $appIdUri } | Remove-AzureADApplication

    # Create AesKey
    $SsoAdAppKeyValue = Create-AesKey
    $AdProperties["SsoAdAppKeyValue"] = $SsoAdAppKeyValue
    $signInReplyUrls = @("$($publicWebBaseUrl.ToLowerInvariant())SignIn")
    $oAuthReplyUrls = @("$($publicWebBaseUrl.ToLowerInvariant())OAuthLanding.htm")
    if ($publicWebBaseUrl.ToUpperInvariant() -cne $publicWebBaseUrl) {
        $signInReplyUrls += @("$($publicWebBaseUrl)SignIn")
        $oAuthReplyUrls += @("$($publicWebBaseUrl)OAuthLanding.htm")
    }


    Write-Host "Creating AAD App for WebClient"
    $ssoAdApp = New-AzureADApplication -DisplayName "WebClient for $publicWebBaseUrl" `
                                       -Homepage $publicWebBaseUrl `
                                       -IdentifierUris $appIdUri `
                                       -ReplyUrls $signInReplyUrls `
                                       -AvailableToOtherTenants (!$SingleTenant.IsPresent)

    $SsoAdAppId = $ssoAdApp.AppId.ToString()
    $AdProperties["SsoAdAppId"] = $SsoAdAppId

    # Add a key to the app
    $startDate = Get-Date
    New-AzureADApplicationPasswordCredential -ObjectId $ssoAdApp.ObjectId `
                                             -Value $SsoAdAppKeyValue `
                                             -StartDate $startDate `
                                             -EndDate $startDate.AddYears(10) | Out-Null

    # Get oauth2 permission id for sso app
    $oauth2permissionid = $ssoAdApp.Oauth2Permissions.id

    $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
    $req1.ResourceAppId = "00000003-0000-0000-c000-000000000000"                                                                              # Microsoft Graph
    $req1.ResourceAccess = @(
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "e1fe6dd8-ba31-4d61-89e7-88639da4683d","Scope"       # User.Read
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "9769c687-087d-48ac-9cb3-c37dde652038","Scope"       # EWS.AccessAsUser.All
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "5fa075e9-b951-4165-947b-c63396ff0a37","Scope"       # PrinterShare.ReadBasic.All
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "21f0d9c0-9f13-48b3-94e0-b6b231c7d320","Scope"       # PrintJob.Create
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "6a71a747-280f-4670-9ca0-a9cbf882b274","Scope"       # PrintJob.ReadBasic
    )

    $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
    $req2.ResourceAppId = "00000009-0000-0000-c000-000000000000"                                                                              # Power BI Service
    $req2.ResourceAccess = 
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "4ae1bf56-f562-4747-b7bc-2fa0874ed46f","Scope"       # Report.Read.All

    $req3 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
    $req3.ResourceAppId = "00000003-0000-0ff1-ce00-000000000000"                                                                              # SharePoint
    $req3.ResourceAccess = @(
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "640ddd16-e5b7-4d71-9690-3f4022699ee7","Scope"       # AllSites.Write
        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2cfdc887-d7b4-4798-9b33-3d98d6b95dd2","Scope"       # MyFiles.Write
#        New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "0cea5a30-f6f8-42b5-87a0-84cc26822e02","Scope"       # User.Read.All
    )

    # Dynamics 365 Business Central -> Delegated permissions for Access as the signed-in user (Financials.ReadWrite.All)
    # Dynamics 365 Business Central -> Application permissions for Full access to Web Services API (API.ReadWrite.All)
    # Dynamics 365 Business Central -> Application permissions Full access to automation (Automation.ReadWrite.All)
#    $req4 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
#    $req4.ResourceAppId = "996def3d-b36c-4153-8607-a6fd3c01b89f"                                                                              # Business Central
#    if ($IncludeApiAccess) {
#        $req4.ResourceAccess = @(
#            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2fb13c28-9d89-417f-9af2-ec3065bc16e6","Scope"   # Financials.ReadWrite.All
#            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "a42b0b75-311e-488d-b67e-8fe84f924341","Role"    # API.ReadWrite.All
#            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "d365bc00-a990-0000-00bc-160000000001","Role"    # Automation.ReadWrite.All
#        )
#    }
#    else {
#        $req4.ResourceAccess =
#            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2fb13c28-9d89-417f-9af2-ec3065bc16e6","Scope"   # Financials.ReadWrite.All
#    }

    Set-AzureADApplication `
        -ObjectId $ssoAdApp.ObjectId `
        -RequiredResourceAccess @($req1, $req2, $req3)

    if ($preAuthorizePowerShell) {
#        $msGraph = Get-AzureADServicePrincipal -All $true | Where-Object { $_.AppId -eq "00000003-0000-0000-c000-000000000000" }
#        $permission = $msGraph.Oauth2Permissions | Where-Object { $_.value -eq "User.Read" }
#        $myapp = Get-AzureADApplication -ObjectId $ssoAdApp.ObjectId
#        $myapp.Oauth2Permissions.Add($permission)
#        Set-AzureADApplication -ObjectId $ssoAdApp.ObjectId -Oauth2Permissions $myapp.Oauth2Permissions

        $appRegistration = Get-AzureADMSApplication -Filter "id eq '$($ssoAdApp.ObjectId)'"
        $preAuthorizedApplication = New-Object 'Microsoft.Open.MSGraph.Model.PreAuthorizedApplication'
        $preAuthorizedApplication.AppId = "1950a258-227b-4e31-a9cf-717495945fc2"
        $preAuthorizedApplication.DelegatedPermissionIds = @($appRegistration.Api.OAuth2PermissionScopes.Id)
        $appRegistration.Api.PreAuthorizedApplications = New-Object 'System.Collections.Generic.List[Microsoft.Open.MSGraph.Model.PreAuthorizedApplication]'
        $appRegistration.Api.PreAuthorizedApplications.Add($preAuthorizedApplication)
        Set-AzureADMSApplication -ObjectId $ssoAdApp.ObjectId -Api $appRegistration.Api
    }

#    if ($IncludeApiAccess) {
#        # Grant admin consent
#        $servicePrincipal = Get-AzureADServicePrincipal -All $true | Where-Object { $_.AppId -eq $SsoAdAppId }
#        if (!($servicePrincipal)) {
#            $servicePrincipal = New-AzureADServicePrincipal -AppId $SsoAdAppId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")
#        }
#        $resourceApp = Get-AzureADServicePrincipal -All $true | Where-Object { $_.AppId -eq $req2.ResourceAppId }
#        ForEach ($permission in $req2.ResourceAccess) {
#            if ($permission.Type -eq "Role") {
#                New-AzureADServiceAppRoleAssignment -ObjectId $servicePrincipal.ObjectId -PrincipalId $servicePrincipal.ObjectId -ResourceId $resourceApp.ObjectId -Id $permission.Id
#            }
#        }
#    }

    if ($IncludeApiAccess) {
        # Create an application role of given name and description
        $appRoleId = [Guid]::NewGuid().ToString()
        # Create new AppRole object
        $appRole = [Microsoft.Open.AzureAD.Model.AppRole]::new()
        $appRole.AllowedMemberTypes = New-Object System.Collections.Generic.List[string]
        $appRole.AllowedMemberTypes.Add("Application")
        $appRole.AllowedMemberTypes.Add("User")
        $appRole.DisplayName = "API.ReadWrite.All"
        $appRole.Description = "Full access to web services API"
        $appRole.Value = "API.ReadWrite.All"
        $appRole.Id = $appRoleId
        $appRole.IsEnabled = $true

        Set-AzureADApplication -ObjectId $ssoAdApp.ObjectId -AppRoles @($appRole)
    }

    # Set Logo Image for App
    if ($iconPath) {
        Set-AzureADApplicationLogo -ObjectId $ssoAdApp.ObjectId -FilePath $iconPath
    }

    if (!(Get-AzureADApplicationOwner -ObjectId $ssoAdApp.ObjectId -All $true | Where-Object { $_.ObjectId -eq $adUserObjectId })) {
        Add-AzureADApplicationOwner -ObjectId $ssoAdApp.ObjectId -RefObjectId $adUserObjectId
    }

    # API Access Aad App
    if ($IncludeApiAccess) {
        # Remove "old" Api AAD Application
        $ApiIdentifierUri = $appIdUri.Replace('://','://api.')
        Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($ApiIdentifierUri) } | Remove-AzureADApplication
    
        # Create AD Application
        Write-Host "Creating AAD App for API Access"
        $apiAdApp = New-AzureADApplication -DisplayName "API Access for $publicWebBaseUrl" `
                                           -HomePage $publicWebBaseUrl `
                                           -IdentifierUris $ApiIdentifierUri `
                                           -ReplyUrls $oAuthReplyUrls `
                                           -AvailableToOtherTenants $true
        
        $apiAdAppId = $apiAdApp.AppId.ToString()
        $AdProperties["ApiAdAppId"] = $apiAdAppId 
    
        # Add a key to the app
        $startDate = Get-Date
        $ApiAdAppKeyValue = Create-AesKey
        $AdProperties["ApiAdAppKeyValue"] = $ApiAdAppKeyValue 
        New-AzureADApplicationPasswordCredential -ObjectId $apiAdApp.ObjectId `
                                                 -Value $apiAdAppKeyValue `
                                                 -StartDate $startDate `
                                                 -EndDate $startDate.AddYears(10) | Out-Null

        $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req1.ResourceAppId = "$SsoAdAppId"
        $req1.ResourceAccess = @(
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "$oauth2permissionid","Scope"
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "$appRoleId","Role"
        )

        $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req2.ResourceAppId = "00000003-0000-0000-c000-000000000000"                                                                              # Microsoft Graph
        $req2.ResourceAccess = 
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "e1fe6dd8-ba31-4d61-89e7-88639da4683d","Scope"       # User.Read

        Set-AzureADApplication -ObjectId $apiAdApp.ObjectId -RequiredResourceAccess $req1, $req2

        # Grant admin consent
        $apiAdAppServicePrincipal = Get-AzureADServicePrincipal -All $true | Where-Object { $_.AppId -eq $apiAdAppId }
        if (!($apiAdAppServicePrincipal)) {
            $apiAdAppServicePrincipal = New-AzureADServicePrincipal -AppId $apiAdAppId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")
        }
        $ssoAdAppServicePrincipal = Get-AzureADServicePrincipal -All $true | Where-Object { $_.AppId -eq $ssoAdAppId }
        if (!($ssoAdAppServicePrincipal)) {
            $ssoAdAppServicePrincipal = New-AzureADServicePrincipal -AppId $SsoAdAppId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")
        }
        ForEach ($permission in $req1.ResourceAccess) {
            if ($permission.Type -eq "Role") {
                New-AzureADServiceAppRoleAssignment -ObjectId $apiAdAppServicePrincipal.ObjectId -PrincipalId $apiAdAppServicePrincipal.ObjectId -ResourceId $ssoAdAppServicePrincipal.ObjectId -Id $permission.Id | Out-Null
            }
        }

        if (!(Get-AzureADApplicationOwner -ObjectId $apiAdApp.ObjectId -All $true | Where-Object { $_.ObjectId -eq $adUserObjectId })) {
            Add-AzureADApplicationOwner -ObjectId $apiAdApp.ObjectId -RefObjectId $adUserObjectId
        }
    }

    # Excel Ad App
    if ($IncludeExcelAadApp) {
        # Remove "old" Excel AD Application
        $ExcelIdentifierUri = $appIdUri.Replace('://','://xls.')
        Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($ExcelIdentifierUri) } | Remove-AzureADApplication

        # Create AD Application
        Write-Host "Creating AAD App for Excel Add-in"
        $excelAdApp = New-AzureADApplication -DisplayName "Excel AddIn for $publicWebBaseUrl" `
                                             -HomePage $publicWebBaseUrl `
                                             -IdentifierUris $ExcelIdentifierUri `
                                             -ReplyUrls ($oAuthReplyUrls+@("https://az689774.vo.msecnd.net/dynamicsofficeapp/v1.3.0.0/*"))

        $ExcelAdAppId = $excelAdApp.AppId.ToString()
        $AdProperties["ExcelAdAppId"] = $ExcelAdAppId

        # Add a key to the app
        $startDate = Get-Date
        $ExcelAdAppKeyValue = Create-AesKey
        $AdProperties["ExcelAdAppKeyValue"] = $ExcelAdAppKeyValue 
        New-AzureADApplicationPasswordCredential -ObjectId $excelAdApp.ObjectId `
                                                 -Value $ExcelAdAppKeyValue `
                                                 -StartDate $startDate `
                                                 -EndDate $startDate.AddYears(10) | Out-Null

        $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req1.ResourceAppId = "$SsoAdAppId"
        $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "$oauth2permissionid","Scope"

        $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req2.ResourceAppId = "00000003-0000-0000-c000-000000000000"                                                                              # Microsoft Graph
        $req2.ResourceAccess = 
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "e1fe6dd8-ba31-4d61-89e7-88639da4683d","Scope"       # User.Read

        Set-AzureADApplication -ObjectId $excelAdApp.ObjectId -Oauth2AllowImplicitFlow $true -RequiredResourceAccess $req1, $req2

        if (!(Get-AzureADApplicationOwner -ObjectId $excelAdApp.ObjectId -All $true | Where-Object { $_.ObjectId -eq $adUserObjectId })) {
            Add-AzureADApplicationOwner -ObjectId $excelAdApp.ObjectId -RefObjectId $adUserObjectId
        }
    }

    # PowerBI Ad App
    if ($IncludePowerBiAadApp) {
        # Remove "old" PowerBI AD Application
        $PowerBiIdentifierUri = $appIdUri.Replace('://','://pbi.')
        Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($PowerBiIdentifierUri) } | Remove-AzureADApplication
    
        # Create AD Application
        Write-Host "Creating AAD App for PowerBI Service"
        $powerBiAdApp = New-AzureADApplication -DisplayName "PowerBI Service for $publicWebBaseUrl" `
                                               -HomePage $publicWebBaseUrl `
                                               -IdentifierUris $PowerBiIdentifierUri `
                                               -ReplyUrls $oAuthReplyUrls `
                                               -AvailableToOtherTenants $true
          
        $PowerBiAdAppId = $powerBiAdApp.AppId.ToString()
        $AdProperties["PowerBiAdAppId"] = $PowerBiAdAppId 
    
        # Add a key to the app
        $startDate = Get-Date
        $PowerBiAdAppKeyValue = Create-AesKey
        $AdProperties["PowerBiAdAppKeyValue"] = $PowerBiAdAppKeyValue 
        New-AzureADApplicationPasswordCredential -ObjectId $powerBiAdApp.ObjectId `
                                                 -Value $PowerBiAdAppKeyValue `
                                                 -StartDate $startDate `
                                                 -EndDate $startDate.AddYears(10) | Out-Null

        $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req1.ResourceAppId = "00000009-0000-0000-c000-000000000000"
        $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "4ae1bf56-f562-4747-b7bc-2fa0874ed46f","Scope"

        $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req2.ResourceAppId = "00000003-0000-0000-c000-000000000000"                                                                              # Microsoft Graph
        $req2.ResourceAccess = 
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "e1fe6dd8-ba31-4d61-89e7-88639da4683d","Scope"       # User.Read

        Set-AzureADApplication -ObjectId $powerBiAdApp.ObjectId -RequiredResourceAccess $req1, $req2

        if (!(Get-AzureADApplicationOwner -ObjectId $powerBiAdApp.ObjectId -All $true | Where-Object { $_.ObjectId -eq $adUserObjectId })) {
            Add-AzureADApplicationOwner -ObjectId $powerBiAdApp.ObjectId -RefObjectId $adUserObjectId
        }
    }

    # EMail App
    if ($IncludeEmailAadApp) {
        # Remove "old" Email AD Application
        $EMailIdentifierUri = $appIdUri.Replace('://','://email.')
        $EMailDisplayName = "EMail Service for $publicWebBaseUrl"
        Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($EMailIdentifierUri) } | Remove-AzureADApplication
    
        # Create AD Application
        Write-Host "Creating AAD App for EMail Service"
        $EMailAdApp = New-AzureADApplication -DisplayName $EMailDisplayName `
                                             -HomePage $publicWebBaseUrl `
                                             -IdentifierUris $EMailIdentifierUri `
                                             -ReplyUrls $oAuthReplyUrls `
                                             -AvailableToOtherTenants $true
        
        $EMailAdAppId = $EMailAdApp.AppId.ToString()
        $AdProperties["EMailAdAppId"] = $EMailAdAppId 
    
        # Add a key to the app
        $startDate = Get-Date
        $EMailAdAppKeyValue = Create-AesKey
        $AdProperties["EMailAdAppKeyValue"] = $EMailAdAppKeyValue 
        New-AzureADApplicationPasswordCredential -ObjectId $EMailAdApp.ObjectId `
                                                 -Value $EMailAdAppKeyValue `
                                                 -StartDate $startDate `
                                                 -EndDate $startDate.AddYears(10) | Out-Null

        $req = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req.ResourceAppId = "00000003-0000-0000-c000-000000000000"
        $req.ResourceAccess = @(
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0","Scope"
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "e383f46e-2787-4529-855e-0e479a3ffac0","Scope"
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "024d486e-b451-40bb-833d-3e66d98c5c73","Scope"
            New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "e1fe6dd8-ba31-4d61-89e7-88639da4683d","Scope"
        )

        Set-AzureADApplication -ObjectId $EMailAdApp.ObjectId -RequiredResourceAccess $req

        if (!(Get-AzureADApplicationOwner -ObjectId $EMailAdApp.ObjectId -All $true | Where-Object { $_.ObjectId -eq $adUserObjectId })) {
            Add-AzureADApplicationOwner -ObjectId $EMailAdApp.ObjectId -RefObjectId $adUserObjectId
        }
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
