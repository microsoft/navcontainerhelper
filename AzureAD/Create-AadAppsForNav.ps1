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
  Create-AadAppsForNAV -AadAdminCredential Get-Credential -appIdUri https://mycontainer/nav/
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

    $iconchars = $null
    if ($iconPath) {
        $iconChars = [char[]][System.IO.File]::ReadAllBytes($iconPath)
    }

    if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
        Write-Host "Installing NuGet Package Provider"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -WarningAction Ignore | Out-Null
    }

    if (!(Get-Package -Name AzureRM.ApiManagement -ErrorAction Ignore)) {
        Write-Host "Installing AzureRM.ApiManagement PowerShell package"
        Install-Package AzureRM.ApiManagement -Force -WarningAction Ignore | Out-Null
    }

    if (!(Get-Package -Name AzureRM.Resources -ErrorAction Ignore)) {
        Write-Host "Installing AzureRM.Resources PowerShell package (if this fails, you probably need to update the PowerShellGet module)"
        Install-Package AzureRM.Resources -Force -WarningAction Ignore | Out-Null
    }

    # Login to AzureRm
    $account = Add-AzureRmAccount -Credential $AadAdminCredential
    $AdProperties = @{}
    $adUserObjectId = 0

    try {
        $aadDomain = $AadAdminCredential.UserName.Split("@")[1]
        $aadTenant = ((New-Object System.Net.WebClient).DownloadString("https://login.windows.net/$aadDomain/.well-known/openid-configuration") | ConvertFrom-Json).token_endpoint.Split('/')[3]
        $AdProperties["AadTenant"] = $AadTenant
        Set-AzureRmContext -Tenant $AadTenant | Out-Null
        $adUser = Get-AzureRmADUser -UserPrincipalName $AadAdminCredential.UserName
        $adUserObjectId = $adUser.Id
    } catch {
        Write-Host "Identifying AAD Tenant ID"
        foreach($tenant in $account.Context.Account.Tenants) {
            try {
                Write-Host -NoNewline "Trying $tenant"
                $AadTenant = $tenant
                $AdProperties["AadTenant"] = $AadTenant
                Set-AzureRmContext -Tenant $AadTenant | Out-Null
                $adUser = Get-AzureRmADUser -UserPrincipalName $account.Context.Account.Id
                $adUserObjectId = $adUser.Id
                Write-Host " - Success"
                break
            } catch {
                Write-Host " - Failure"
            }
        }
    }

    if (!$adUserObjectId) {
        throw "Could not identify Aad Tenant ID"
    }

    $graphUrl = "https://graph.windows.net"
    $apiversion = "1.6"

    $authority = "https://login.microsoftonline.com/$AadTenant"

    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"  # Set well-known client ID for AzurePowerShell
    $resourceAppIdURI = "$graphUrl/" # resource we want to use
    
    # Create Authentication Context tied to Azure AD Tenant
    Write-Host "Authenticate and create authorization headers (requires Microsoft.IdentityMOdel.Clients.ActiveDirectory)"
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $userCred = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential" -ArgumentList $AadAdminCredential.UserName, $AadAdminCredential.Password
    
    # Acquire token and create authentication headers
    $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $userCred)
    $authHeader = $authResult.CreateAuthorizationHeader()
    $headers = @{"Authorization" = $authHeader; "Content-Type"="application/json"}    

    # Remove "old" AD Application
    Get-AzureRmADApplication -IdentifierUri $appIdUri | Remove-AzureRmADApplication -Force

    # Create AesKey
    $SsoAdAppKeyValue = Create-AesKey
    $AdProperties["SsoAdAppKeyValue"] = $SsoAdAppKeyValue

    Write-Host "Creating AAD App for WebClient"
    $ssoAdApp = New-AzureRmADApplication –DisplayName "NAV WebClient for $appIdUri" `
                                         -HomePage $publicWebBaseUrl `
                                         -IdentifierUris $appIdUri `
                                         -ReplyUrls $publicWebBaseUrl
    
    $SsoAdAppId = $ssoAdApp.ApplicationId.ToString()
    $AdProperties["SsoAdAppId"] = $SsoAdAppId

    # Add a key to the app
    $startDate = Get-Date
    New-AzureRmADAppCredential -ApplicationId $SsoAdAppId `
                               -Password (ConvertTo-SecureString -string $SsoAdAppKeyValue -AsPlainText -Force) `
                               -StartDate $startDate `
                               -EndDate $startDate.AddYears(10) | Out-Null

    # Get oauth2 permission id for sso app
    $url = ("$graphUrl/$aadTenant/applications/$($ssoAdApp.ObjectID)?api-version=$apiversion")
    $result = Invoke-RestMethod -Uri $url -Method "GET" -Headers $headers
    $oauth2permissionid = $result.oauth2Permissions.id
    
    # Add Required Resource Access
    $ssoUrl = "$graphUrl/$AadTenant/applications/$($ssoAdApp.ObjectID)?api-version=$apiversion"

    $ssoPostData = @{"requiredResourceAccess" = @(
         @{ 
            "resourceAppId" = "00000002-0000-0000-c000-000000000000"; 
            "resourceAccess" = @( @{
              "id" = "311a71cc-e848-46a1-bdf8-97ff7156d8e6";
              "type" = "Scope"
            }
            )
         }
      )} | ConvertTo-Json -Depth 99

    # Invoke-RestMethod will not close the connection properly and as such will only allow 2 subsequent calls to Invoke-RestMethod
    # This is why we use Invoke-WebRequest and getting the response content
    (Invoke-WebRequest -UseBasicParsing -Method PATCH -ContentType 'application/json' -Headers $headers -Uri $ssoUrl -Body $ssoPostData).Content | Out-Null

    # Set Logo Image for App
    if ($iconChars) {
        $url = "$graphUrl/$AadTenant/applications/$($ssoAdApp.ObjectID)/mainLogo?api-version=$apiversion"
        $iconStr = -join $iconChars
        (Invoke-WebRequest -UseBasicParsing -Method PUT -ContentType 'image/Png' -Headers $headers -Uri $url -Body $iconStr).Content | Out-Null
    }


    # Excel Ad App
    if ($IncludeExcelAadApp) {
        # Remove "old" Excel AD Application
        $ExcelIdentifierUri = "${appIdUri}ExcelAddIn"
        Get-AzureRmADApplication -IdentifierUri $ExcelIdentifierUri | Remove-AzureRmADApplication -Force

        # Create AD Application
        Write-Host "Creating AAD App for Excel Add-in"
        $excelAdApp = New-AzureRmADApplication –DisplayName "Excel AddIn for $appIdUri" `
                                               -HomePage $publicWebBaseUrl `
                                               -IdentifierUris $ExcelIdentifierUri `
                                               -ReplyUrls $publicWebBaseUrl, "https://az689774.vo.msecnd.net/dynamicsofficeapp/v1.3.0.0/*"

        $ExcelAdAppId = $excelAdApp.ApplicationId.ToString()
        $AdProperties["ExcelAdAppId"] = $ExcelAdAppId

        # Add Required Resource Access
        $excelUrl = "$graphUrl/$AadTenant/applications/$($excelAdApp.ObjectID)?api-version=$apiversion"

        $excelPostData = @{
          "oauth2AllowImplicitFlow" = $true;
          "requiredResourceAccess" = @(
             @{ 
                "resourceAppId" = "$SsoAdAppId"; 
                "resourceAccess" = @( @{
                  "id" = "$oauth2permissionid";
                  "type" = "Scope"
                })
             },
             @{ 
                "resourceAppId" = "00000002-0000-0000-c000-000000000000"; 
                "resourceAccess" = @( @{
                  "id" = "311a71cc-e848-46a1-bdf8-97ff7156d8e6";
                  "type" = "Scope"
                })
             }
          )} | ConvertTo-Json -Depth 99

        (Invoke-WebRequest -UseBasicParsing -Method PATCH -ContentType 'application/json' -Headers $headers -Uri $excelUrl   -Body $excelPostData).Content | Out-Null

        # Check if owner already exists
        $excelLinkedOwnerUrl = "$graphUrl/$AadTenant/applications/$($excelAdApp.ObjectID)/owners?api-version=$apiversion"
        $JsonResponse = ((Invoke-WebRequest -UseBasicParsing -Method Get -ContentType 'application/json' -Headers $headers -Uri $excelLinkedOwnerUrl).Content | ConvertFrom-Json).value
        if(($JsonResponse | Where-Object {$_.objectId -eq $adUserObjectId}) -eq $null){

            # Add owner to Azure Ad Application
            $excelOwnerUrl = "$graphUrl/$AadTenant/applications/$($excelAdApp.ObjectID)/`$links/owners?api-version=$apiversion"
            $excelOwnerPostData  = @{
            "url" = "$graphUrl/$AadTenant/directoryObjects/$adUserObjectId/Microsoft.DirectoryServices.User?api-version=$apiversion"
            } | ConvertTo-Json -Depth 99
    
            (Invoke-WebRequest -UseBasicParsing -Method POST -ContentType 'application/json' -Headers $headers -Uri $excelOwnerUrl -Body $excelOwnerPostData -ErrorAction Ignore).Content | Out-Null            
        }
    }

    # PowerBI Ad App
    if ($IncludePowerBiAadApp) {
        # Remove "old" PowerBI AD Application
        $PowerBiIdentifierUri = "${appIdUri}PowerBI"
        Get-AzureRmADApplication -IdentifierUri $PowerBiIdentifierUri | Remove-AzureRmADApplication -Force
    
        # Create AesKey
        $PowerBiAdAppKeyValue = Create-AesKey
        $AdProperties["PowerBiAdAppKeyValue "] = $PowerBiAdAppKeyValue 
    
        # Create AD Application
        Write-Host "Creating AAD App for PowerBI Service"
        $powerBiAdApp = New-AzureRmADApplication –DisplayName "PowerBI Service for $appIdUri" `
                                                 -HomePage $publicWebBaseUrl `
                                                 -IdentifierUris $PowerBiIdentifierUri `
                                                 -ReplyUrls "${publicWebBaseUrl}OAuthLanding.htm"
        
        $PowerBiAdAppId = $powerBiAdApp.ApplicationId.ToString()
        $AdProperties["PowerBiAdAppId"] = $PowerBiAdAppId 
    
        # Add a key to the app
        $startDate = Get-Date
        New-AzureRmADAppCredential -ApplicationId $PowerBIAdAppId `
                                   -Password (ConvertTo-SecureString -string $PowerBiAdAppKeyValue -AsPlainText -Force) `
                                   -StartDate $startDate `
                                   -EndDate $startDate.AddYears(10) | Out-Null
        
        # Add Required Resource Access
        $powerBiUrl = "$graphUrl/$AadTenant/applications/$($powerBiAdApp.ObjectID)?api-version=$apiversion"
        $powerBiPostData = @{"requiredResourceAccess" = @(
             @{ 
                "resourceAppId" = "00000009-0000-0000-c000-000000000000"; 
                "resourceAccess" = @( @{
                  "id" = "4ae1bf56-f562-4747-b7bc-2fa0874ed46f";
                  "type" = "Scope"
                })
             },
             @{ 
                "resourceAppId" = "00000002-0000-0000-c000-000000000000"; 
                "resourceAccess" = @( @{
                  "id" = "311a71cc-e848-46a1-bdf8-97ff7156d8e6";
                  "type" = "Scope"
                })
             }
          )} | ConvertTo-Json -Depth 99
        
        (Invoke-WebRequest -UseBasicParsing -Method PATCH -ContentType 'application/json' -Headers $headers -Uri $powerBiUrl -Body $powerBiPostData).Content | Out-Null
    }

    $AdProperties
}
Export-ModuleMember -Function Create-AadAppsForNav
