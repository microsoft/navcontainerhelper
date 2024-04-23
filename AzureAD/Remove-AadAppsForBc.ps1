<# 
 .Synopsis
  Remove Apps in Azure Active Directory to clean up the AAD
 .Description
  This function will remove the apps in AAD for Web and Windows Client to use AAD for authentication,
  the API Integration, the Excel AddIn and the PowerBI integration
 .Parameter accessToken
  Accesstoken for Microsoft Graph with permissions to create apps in the AAD
 .Parameter appIdUri
  Unique Uri to identify the AAD App (typically we use the URL for the Web Client)
 .Parameter useCurrentMicrosoftGraphConnection
  Specify this switch to use the current Microsoft Graph Connection instead of invoking Connect-MgGraph (which will pop up a UI)
 .Example
  Remove-AadAppsForBc -accessToken $accessToken -appIdUri https://mycontainer.mydomain/bc/
 .Example
  $bcAuthContext = New-BcAuthContext -tenantID $azureTenantId -clientID $azureApplicationId -clientSecret $clientSecret -scopes "https://graph.microsoft.com/.default"
  $AdProperties = Remove-AadAppsForBc -appIdUri https://mycontainer.mydomain/bc/ -bcAuthContext $bcAuthContext 
#>
function Remove-AadAppsForBc {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $accessToken,
        [Parameter(Mandatory=$true)]
        [string] $appIdUri,
        [switch] $useCurrentMicrosoftGraphConnection,
        [Hashtable] $bcAuthContext
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
        Write-Host "Installing NuGet Package Provider"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -WarningAction Ignore | Out-Null
    }

    if (!(Get-Package -Name Microsoft.Graph -ErrorAction Ignore)) {
        Write-Host "Installing Microsoft.Graph PowerShell package"
        Install-Package Microsoft.Graph -Force -WarningAction Ignore | Out-Null
    }

    # Check the AccessToken since Microsoft Graph V2 requires a SecureString
    $graphAccesTokenParameter = (Get-Command Connect-MgGraph).Parameters['AccessToken']
  
    if ($graphAccesTokenParameter.ParameterType -eq [securestring]){
        $useSecureStringForAccessToken = $true
        if ($accessToken) {
            $accessToken = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
        }
    }

    # Connect to Microsoft.Graph
    if (!$useCurrentMicrosoftGraphConnection) {
        if ($bcAuthContext) {
            $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
            $jwtToken = Parse-JWTtoken -token $bcAuthContext.accessToken
            if ($jwtToken.aud -ne 'https://graph.microsoft.com') {
                Write-Host -ForegroundColor Yellow "The accesstoken was provided for $($jwtToken.aud), should have been for https://graph.microsoft.com"
            }
            $accessToken = $bcAuthContext.accessToken
        }
        if ($accessToken) {
            if ($useSecureStringForAccessToken){
                Connect-MgGraph -AccessToken (ConvertTo-SecureString -String $accessToken -AsPlainText -Force) | Out-Null
            }
            else {
                Connect-MgGraph -AccessToken $accessToken | Out-Null
            }
        }
        else {
            Connect-MgGraph -Scopes 'Application.ReadWrite.All' | Out-Null
        }
    }
    $account = Get-MgContext

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

    # Remove "old" Api AAD Application
    Write-Host "Remove AAD App for Api"
    $ApiIdentifierUri = $appIdUri.Replace('://','://api.')
    Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $ApiIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

    # Remove "old" Excel AD Application
    Write-Host "Remove AAD App for Excel"
    $ExcelIdentifierUri = $appIdUri.Replace('://','://xls.')
    Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $ExcelIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

    # Remove "old" PowerBI AD Application
    Write-Host "Remove AAD App for PowerBI"
    $PowerBiIdentifierUri = $appIdUri.Replace('://','://pbi.')
    Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $PowerBiIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

    # Remove "old" Email AD Application
    Write-Host "Remove AAD App for EMail Service"
    $EMailIdentifierUri = $appIdUri.Replace('://','://email.')
    Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $EMailIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }
    
    # Remove "old" Other Services AD Application
    $OtherServicesIdentifierUri = $appIdUri.Replace('://','://other.')
    Get-MgApplication -All | Where-Object { $_.IdentifierUris -contains $OtherServicesIdentifierUri } | ForEach-Object { Remove-MgApplication -ApplicationId $_.Id }

}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Remove-AadAppsForBc
