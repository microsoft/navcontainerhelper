<# 
 .Synopsis
  Create Apps in Azure Active Directory to allow Single Signon with NAV using AAD
 .Description
  This function will create an app in AAD, to allow NAV Web and Windows Client to use AAD for authentication
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
 .Example
  Create-AadAppsForNAV -AadAdminCredential (Get-Credential) -appIdUri https://mycontainer/nav/
#>
function Create-AadAppsForNav
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$AadAdminCredential,
        [Parameter(Mandatory=$true)]
        [string]$appIdUri,
        [Parameter(Mandatory=$false)]
        [string]$publicWebBaseUrl = $appIdUri,
        [Parameter(Mandatory=$false)]
        [string]$iconPath,
        [switch]$IncludeExcelAadApp,
        [switch]$IncludePowerBiAadApp
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

    # Login to AzureRm
    $account = Connect-AzureAD -Credential $AadAdminCredential
    $AdProperties = @{}
    $adUserObjectId = 0

    $aadDomain = $account.TenantDomain
    $aadTenant = $account.TenantId
    $AdProperties["AadTenant"] = $AadTenant

    $adUser = Get-AzureADUser -ObjectId $aadadmincredential.UserName
    if (!$adUser) {
        throw "Could not identify Aad Tenant"
    }

    $adUserObjectId = $adUser.ObjectId
    
    # Remove "old" AD Application
    Get-AzureADApplication -All $true | Where-Object { $_.IdentifierUris.Contains($appIdUri) } | Remove-AzureADApplication

    # Create AesKey
    $SsoAdAppKeyValue = Create-AesKey
    $AdProperties["SsoAdAppKeyValue"] = $SsoAdAppKeyValue

    Write-Host "Creating AAD App for WebClient"
    $ssoAdApp = New-AzureADApplication -DisplayName "NAV WebClient for $appIdUri" `
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

    $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess" 
    $req1.ResourceAppId = "00000002-0000-0000-c000-000000000000"
    $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"

    Set-AzureADApplication -ObjectId $ssoAdApp.ObjectId -RequiredResourceAccess @($req1)

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
        $excelAdApp = New-AzureADApplication –DisplayName "Excel AddIn for $appIdUri" `
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
        $powerBiAdApp = New-AzureADApplication –DisplayName "PowerBI Service for $appIdUri" `
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

    $AdProperties
}
Export-ModuleMember -Function Create-AadAppsForNav
