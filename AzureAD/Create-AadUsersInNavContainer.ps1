<# 
 .Synopsis
  Enumerate users in AAD and create them in NAV/BC Container
 .Description
  This function will create an app in AAD, to allow Web and Windows Client to use AAD for authentication
  Optionally the function can also create apps for the Excel AddIn and/or PowerBI integration
 .Parameter containerName
  Name of the container in which you want to create the users (default navserver)
 .Parameter tenant
  Name of tenant in which you want to create a users
 .Parameter AadAdminCredential
  Credentials for your AAD/Office 365 administrator user, who can enumerate users in the AAD
 .Parameter ChangePasswordAtNextLogOn
  Switch to indicate that the users needs to change password at next login (if using NavUserPassword authentication)
 .Parameter PermissionSetId
  Name of the permissionSetId to assign to the user (default is SUPER)
 .Parameter SecurePassword
  Default password for all users
 .Parameter useCurrentAzureAdConnection
  Specify this switch to use the current Azure AD Connection instead of invoking Connect-AzureAD (which will pop up a UI)
 .Example
  Create-AadUsersInBcContainer -containerName test -AadAdminCredential (Get-Credential)
#>
function Create-AadUsersInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [PSCredential] $AadAdminCredential,
        [bool] $ChangePasswordAtNextLogOn = $true,
        [string] $permissionSetId = "SUPER",
        [Parameter(Mandatory=$true)]
        [Securestring] $securePassword,
        [switch] $useCurrentAzureAdConnection
    )
    
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

    Get-AzureADUser -All $true | Where-Object { $_.AccountEnabled } | ForEach-Object {
        $userName = $_.MailNickName
        $authenticationEMail = $_.UserPrincipalName
        if (Get-BcContainerNavUser -containerName $containerName -tenant $tenant | Where-Object { $_.UserName -eq $userName -or $_.AuthenticationEmail -eq $authenticationEMail }) {
            Write-Host "User $userName already exists"
        } else {
            $Credential = [System.Management.Automation.PSCredential]::new($userName, $securePassword)
            New-BcContainerNavUser -containerName $containerName -tenant $tenant -AuthenticationEmail $authenticationEMail -Credential $Credential -PermissionSetId $permissionSetId -ChangePasswordAtNextLogOn $ChangePasswordAtNextLogOn
        }
    }
}
Set-Alias -Name Create-AadUsersInNavContainer -Value Create-AadUsersInBcContainer
Export-ModuleMember -Function Create-AadUsersInBcContainer -Alias Create-AadUsersInNavContainer
