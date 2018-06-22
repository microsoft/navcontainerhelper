<# 
 .Synopsis
  Enumerate users in AAD and create them in NAV Container
 .Description
  This function will create an app in AAD, to allow NAV Web and Windows Client to use AAD for authentication
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
 .Example
  Create-AadUsersInNavContainer -containerName test -AadAdminCredential (Get-Credential)
#>
function Create-AadUsersInNavContainer
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$AadAdminCredential,
        [parameter(Mandatory=$false)]
        [bool]$ChangePasswordAtNextLogOn = $true,
        [Parameter(Mandatory=$false)]
        [string]$permissionSetId = "SUPER",
        [Parameter(Mandatory=$false)]
        [Securestring]$securePassword = $AadAdminCredential.Password
    )
    
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
    Get-AzureADUser | Where-Object { $_.AccountEnabled } | ForEach-Object {
        $userName = $_.MailNickName
        if (Get-NavContainerNavUser -containerName $containerName -tenant $tenant | Where-Object { $_.UserName -eq $userName }) {
            Write-Host "User $userName already exists"
        } else {
            $Credential = [System.Management.Automation.PSCredential]::new($userName, $securePassword)
            New-NavContainerNavUser -containerName $containerName -tenant $tenant -AuthenticationEmail $_.UserPrincipalName -Credential $Credential -PermissionSetId $permissionSetId -ChangePasswordAtNextLogOn $ChangePasswordAtNextLogOn
        }
    }
}
Export-ModuleMember -Function Create-AadUsersInNavContainer
