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
 .Parameter useCurrentAzureAdConnection
  Specify this switch to use the current Azure AD Connection instead of invoking Connect-AzureAD (which will pop up a UI)
 .Example
  Create-AadAppsForNAV -AadAdminCredential (Get-Credential) -appIdUri https://mycontainer/bc/
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
        Connect-AzureAD -AadAccessToken $bcAuthContext.accessToken -AccountId $jwtToken.upn
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

    Write-Host "Creating AAD App for WebClient"
    $ssoAdApp = New-AzureADApplication -DisplayName "WebClient for $appIdUri" `
                                       -Homepage $publicWebBaseUrl `
                                       -IdentifierUris $appIdUri `
                                       -ReplyUrls @($publicWebBaseUrl, ($publicWebBaseUrl.ToLowerInvariant()+"SignIn"))

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

    # Windows Azure Active Directory -> Delegated permissions for Sign in and read user profile (User.Read)
    $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
    $req1.ResourceAppId = "00000002-0000-0000-c000-000000000000"
    $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"

    # Dynamics 365 Business Central -> Delegated permissions for Access as the signed-in user (Financials.ReadWrite.All)
    $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
    $req2.ResourceAppId = "996def3d-b36c-4153-8607-a6fd3c01b89f"
    $req2.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2fb13c28-9d89-417f-9af2-ec3065bc16e6","Scope"

    Set-AzureADApplication -ObjectId $ssoAdApp.ObjectId -RequiredResourceAccess @($req1, $req2)

    # Set Logo Image for App
    if ($iconPath) {
        Set-AzureADApplicationLogo -ObjectId $ssoAdApp.ObjectId -FilePath $iconPath
    }

    # Excel Ad App
    if ($IncludeExcelAadApp) {
        # Remove "old" Excel AD Application
        $ExcelIdentifierUri = "${appIdUri}ExcelAddIn"
        Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($ExcelIdentifierUri) } | Remove-AzureADApplication

        # Create AD Application
        Write-Host "Creating AAD App for Excel Add-in"
        $excelAdApp = New-AzureADApplication -DisplayName "Excel AddIn for $appIdUri" `
                                             -HomePage $publicWebBaseUrl `
                                             -IdentifierUris $ExcelIdentifierUri `
                                             -ReplyUrls $publicWebBaseUrl, "https://az689774.vo.msecnd.net/dynamicsofficeapp/v1.3.0.0/*"

        $ExcelAdAppId = $excelAdApp.AppId.ToString()
        $AdProperties["ExcelAdAppId"] = $ExcelAdAppId

        $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req1.ResourceAppId = "$SsoAdAppId"
        $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "$oauth2permissionid","Scope"

        $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
        $req2.ResourceAppId = "00000002-0000-0000-c000-000000000000"
        $req2.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"

        Set-AzureADApplication -ObjectId $excelAdApp.ObjectId -Oauth2AllowImplicitFlow $true -RequiredResourceAccess $req1, $req2

        if (!(Get-AzureADApplicationOwner -ObjectId $excelAdApp.ObjectId -All $true | Where-Object { $_.ObjectId -eq $adUserObjectId })) {
            Add-AzureADApplicationOwner -ObjectId $excelAdApp.ObjectId -RefObjectId $adUserObjectId
        }
    }

    # PowerBI Ad App
    if ($IncludePowerBiAadApp) {
        # Remove "old" PowerBI AD Application
        $PowerBiIdentifierUri = "${appIdUri}PowerBI"
        Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($PowerBiIdentifierUri) } | Remove-AzureADApplication
    
        # Create AesKey
        $PowerBiAdAppKeyValue = Create-AesKey
        $AdProperties["PowerBiAdAppKeyValue"] = $PowerBiAdAppKeyValue 
    
        # Create AD Application
        Write-Host "Creating AAD App for PowerBI Service"
        $powerBiAdApp = New-AzureADApplication -DisplayName "PowerBI Service for $appIdUri" `
                                               -HomePage $publicWebBaseUrl `
                                               -IdentifierUris $PowerBiIdentifierUri `
                                               -ReplyUrls "${publicWebBaseUrl}OAuthLanding.htm"
        
        $PowerBiAdAppId = $powerBiAdApp.AppId.ToString()
        $AdProperties["PowerBiAdAppId"] = $PowerBiAdAppId 
    
        # Add a key to the app
        $startDate = Get-Date
        New-AzureADApplicationPasswordCredential -ObjectId $powerBiAdApp.ObjectId `
                                                 -Value $PowerBiAdAppKeyValue `
                                                 -StartDate $startDate `
                                                 -EndDate $startDate.AddYears(10) | Out-Null

        $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
        $req1.ResourceAppId = "00000009-0000-0000-c000-000000000000"
        $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "4ae1bf56-f562-4747-b7bc-2fa0874ed46f","Scope"

        $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
        $req2.ResourceAppId = "00000002-0000-0000-c000-000000000000"
        $req2.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"

        Set-AzureADApplication -ObjectId $powerBiAdApp.ObjectId -RequiredResourceAccess $req1, $req2
    }

    # EMail App
    if ($IncludeEmailAadApp) {
        # Remove "old" Email AD Application
        #$EmailIdentifierUri = "${appIdUri}EMail"
        $EMailDisplayName = "EMail Service for $appIdUri"
        Get-AzureADApplication -All $true | Where-Object { $_.DisplayName -eq $EMailDisplayName } | Remove-AzureADApplication
    
        # Create AesKey
        $EMailAdAppKeyValue = Create-AesKey
        $AdProperties["EMailAdAppKeyValue"] = $EMailAdAppKeyValue 
    
        # Create AD Application
        Write-Host "Creating AAD App for EMail Service"
        $EMailAdApp = New-AzureADApplication -DisplayName $EMailDisplayName `
                                             -HomePage $publicWebBaseUrl `
                                             -ReplyUrls "${publicWebBaseUrl}OAuthLanding.htm" `
                                             -AvailableToOtherTenants 1
        
        $EMailAdAppId = $EMailAdApp.AppId.ToString()
        $AdProperties["EMailAdAppId"] = $EMailAdAppId 
    
        # Add a key to the app
        $startDate = Get-Date
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
    }

    $AdProperties
}
Set-Alias -Name Create-AadAppsForBC -Value Create-AadAppsForNav
Export-ModuleMember -Function Create-AadAppsForNav -Alias Create-AadAppsForBC
