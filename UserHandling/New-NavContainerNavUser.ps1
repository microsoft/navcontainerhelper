<# 
 .Synopsis
  Creates a new User in a NAV/BC Container
 .Description
  Creates a new user in a NAV/BC container.
  If the Container is multitenant, the user will be added to a specified tenant
 .Parameter containerName
  Name of the container in which you want to create the user
 .Parameter tenant
  Name of tenant in which you want to create a user
 .Parameter Credential
  Credentials of the new user (if using NavUserPassword authentication)
 .Parameter WindowsAccount
  WindowsAccount of the new user (if using Windows authentication)
 .Parameter AuthenticationEmail
  AuthenticationEmail of the new user
 .Parameter ChangePasswordAtNextLogOn
  Switch to indicate that the user needs to change password at next login (if using NavUserPassword authentication)
 .Parameter PermissionSetId
  Name of the permissionSetId to assign to the user (default is SUPER)
 .Parameter AssignPremiumPlan
  For sandbox containers only, assign Premium plan to user if this switch is included
 .Parameter databaseCredential
  Database Credential if using AssignPremiumPlan with foreign database connection
 .Example
  New-BcContainerBcUser -containerName test -tenantId mytenant -credential $credential
 .Example
  New-BcContainerBcUser -containerName test -tenantId mytenant -WindowsAccount freddyk -PermissionSetId SUPER
#>
function New-BcContainerBcUser {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [parameter(Mandatory=$true, ParameterSetName="NavUserPassword")]
        [PSCredential] $Credential,
        [parameter(Mandatory=$true, ParameterSetName="Windows")]
        [string] $WindowsAccount,
        [parameter(Mandatory=$false, ParameterSetName="NavUserPassword")]
        [string] $AuthenticationEmail,
        [parameter(Mandatory=$false, ParameterSetName="NavUserPassword")]
        [bool] $ChangePasswordAtNextLogOn = $true,
        [parameter(Mandatory=$false)]        
        [string] $PermissionSetId = "SUPER",
        [switch] $assignPremiumPlan,
        [PSCredential] $databaseCredential
    )

    PROCESS
    {
        Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { param([PSCredential]$Credential, [string]$Tenant, [string]$WindowsAccount, [string]$AuthenticationEMail, [bool]$ChangePasswordAtNextLogOn, [string]$PermissionSetId, $assignPremiumPlan, [PSCredential]$databaseCredential)
                        
            $TenantParam = @{}
            if ($Tenant) {
                $TenantParam.Add('Tenant', $Tenant)
            }
            $Parameters = @{}
            if ($AuthenticationEMail) {
                $Parameters.Add('AuthenticationEmail',$AuthenticationEmail)
            }

            if ($assignPremiumPlan) {

                $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
                [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
                $multitenant = ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -eq "true")
                $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
                $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
                $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
                $databaseServerInstance = $databaseServer
                if ($databaseInstance) {
                    $databaseServerInstance += "\$databaseInstance"
                }
                
                $sqlparams = @{
                    "ErrorAction" = "Ignore"
                }
                if ($databaseServerInstance -ne "localhost\SQLEXPRESS") {
                    if (!($databaseCredential)) {
                        throw "When using a foreign SQL Server, you need to specify databaseCredential in order to assign Premium Plan"
                    }
                    $sqlparams += @{
                        "ServerInstance" = $databaseServerInstance
                        "Username" = $databaseCredential.Username
                        "Password" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($databaseCredential.Password))
                    }
                }
            }

            if($WindowsAccount) {
                Write-Host "Creating User for WindowsAccount $WindowsAccount"
      			New-NAVServerUser -ServerInstance $ServerInstance @TenantParam -WindowsAccount $WindowsAccount @Parameters
                Write-Host "Assigning Permission Set $PermissionSetId to $WindowsAccount"
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance @tenantParam -WindowsAccount $WindowsAccount -PermissionSetId $PermissionSetId
                $user = Get-NAVServerUser -ServerInstance $ServerInstance @tenantParam | Where-Object { $_.UserName.EndsWith("\$WindowsAccount", [System.StringComparison]::InvariantCultureIgnoreCase) -or $_.UserName -eq $WindowsAccount }
            } else {
                Write-Host "Creating User $($Credential.UserName)"
                if ($ChangePasswordAtNextLogOn) {
      			    New-NAVServerUser -ServerInstance $ServerInstance @TenantParam -Username $Credential.UserName -Password $Credential.Password -ChangePasswordAtNextLogon @Parameters
                } else {
      			    New-NAVServerUser -ServerInstance $ServerInstance @TenantParam -Username $Credential.UserName -Password $Credential.Password @Parameters
                }
                Write-Host "Assigning Permission Set $PermissionSetId to $($Credential.Username)"
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance @tenantParam -username $Credential.username -PermissionSetId $PermissionSetId
                $user = Get-NAVServerUser -ServerInstance $ServerInstance @tenantParam | Where-Object { $_.UserName -eq $Credential.UserName }
            }

            if ($assignPremiumPlan -and ($user)) {

                $UserId = $user.UserSecurityId
                Write-Host "Assigning Premium plan for $($user.Username)"
                $dbName = $DatabaseName
                if ($multitenant) {
                    $dbName = (Get-NavTenant -ServerInstance $ServerInstance -tenant $tenant).DatabaseName
                }

                'User Plan$63ca2fa4-4f03-4f2b-a480-172fef340d3f','User Plan' | % {
                    Invoke-Sqlcmd @sqlParams -Query "USE [$DbName]
INSERT INTO [dbo].[$_] ([Plan ID],[User Security ID]) VALUES ('{8e9002c0-a1d8-4465-b952-817d2948e6e2}','$userId')"

                }                   
            }
        } -argumentList $Credential, $Tenant, $WindowsAccount, $AuthenticationEMail, $ChangePasswordAtNextLogOn, $PermissionSetId, $assignPremiumPlan, $databaseCredential
    }
}
Set-Alias -Name New-NavContainerNavUser -Value New-BcContainerBcUser
Export-ModuleMember -Function New-BcContainerBcUser -Alias New-NavContainerNavUser
