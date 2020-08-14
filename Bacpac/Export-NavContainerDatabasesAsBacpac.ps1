<# 
 .Synopsis
  Export databases in a NAV/BC Container as .bacpac files
 .Description
  If the Container is multi-tenant, this command will create an app.bacpac and a tenant.bacpac.
  If the Container is single-tenant, this command will create one bacpac file called database.bacpac.
 .Parameter containerName
  Name of the container for which you want to export and convert objects
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter bacpacFolder
  The folder to which the bacpac files are exported (needs to be shared with the container)
 .Parameter tenant
  The tenant database(s) to export, only applies to multi-tenant containers
  Omit to export tenant template, specify default to export the default tenant.
 .Parameter doNotCheckEntitlements
  Include this parameter to avoid checking entitlements. Entitlements are needed if the .bacpac file is to be used for cloud deployments.
 .Parameter commandTimeout
  Timeout in seconds for the export command for every database. Default is 1 hour (3600).
 .Parameter diagnostics
  Include this switch to enable diagnostics from the database export command
  Timeout in seconds for the export command for every database. Default is 1 hour (3600).
 .Parameter additionalArguments
  Use this parameter to specify additional arguments to sqlpackage.exe
 .Example
  Export-BcContainerDatabasesAsBacpac -containerName test
 .Example
  Export-BcContainerDatabasesAsBacpac -containerName test -bacpacfolder "c:\programdata\bccontainerhelper\extensions\test"
 .Example
  Export-BcContainerDatabasesAsBacpac -containerName test -bacpacfolder "c:\demo" -sqlCredential <sqlCredential>
 .Example
  Export-BcContainerDatabasesAsBacpac -containerName test -tenant default
 .Example
  Export-BcContainerDatabasesAsBacpac -containerName test -tenant @("default","tenant")
#>
function Export-BcContainerDatabasesAsBacpac {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [PSCredential] $sqlCredential = $null,
        [string] $bacpacFolder = "",
        [string[]] $tenant = @("default"),
        [int] $commandTimeout = 3600,
        [switch] $diagnostics,
        [switch] $doNotCheckEntitlements,
        [string[]] $additionalArguments = @()
    )
    
    $genericTag = Get-BcContainerGenericTag -containerOrImageName $containerName
    if ([System.Version]$genericTag -lt [System.Version]"0.0.4.5") {
        throw "Export-DatabasesAsBacpac is not supported in images with generic tag prior to 0.0.4.5"
    }

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    if ("$bacpacFolder" -eq "") {
        $bacpacFolder = $containerFolder
    }
    $containerBacpacFolder = Get-BcContainerPath -containerName $containerName -path $bacpacFolder -throw

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param([PSCredential]$sqlCredential, $bacpacFolder, $tenant, $commandTimeout, $diagnostics, $additionalArguments, $doNotCheckEntitlements)
    
        function InstallPrerequisite {
            Param (
                [Parameter(Mandatory=$true)]
                [string] $Name,
                [Parameter(Mandatory=$true)]
                [string] $MsiPath,
                [Parameter(Mandatory=$true)]
                [string] $MsiUrl
            )
        
            if (!(Test-Path $MsiPath)) {
                Write-Host "Downloading $Name"
                $MsiFolder = [System.IO.Path]::GetDirectoryName($MsiPath)
                if (!(Test-Path $MsiFolder)) {
                    New-Item -Path $MsiFolder -ItemType Directory | Out-Null
                }
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                (New-Object System.Net.WebClient).DownloadFile($MsiUrl, $MsiPath)
            }
            Write-Host "Installing $Name"
            start-process $MsiPath -ArgumentList "/quiet /qn /passive" -Wait
        }

        function Install-DACFx
        {
            $sqlpakcageExe = Get-Item "C:\Program Files\Microsoft SQL Server\*\DAC\bin\sqlpackage.exe" | Sort-Object -Property FullName -Descending | Select-Object -First 1
            if (!($sqlpakcageExe)) {
                InstallPrerequisite -Name "Dac Framework 18.2" -MsiPath "c:\download\DacFramework.msi" -MsiUrl "https://download.microsoft.com/download/9/2/2/9228AAC2-90D1-4F48-B423-AF345296C7DD/EN/x64/DacFramework.msi" | Out-Null
                $sqlpakcageExe = Get-Item "C:\Program Files\Microsoft SQL Server\*\DAC\bin\sqlpackage.exe"
            }
            $sqlpakcageExe.FullName
        }
        
        function Remove-NetworkServiceUser {
            Param (
                [Parameter(Mandatory=$true)]
                [string] $DatabaseName,
                [Parameter(Mandatory=$true)]
                [string] $DatabaseServer,
                [Parameter(Mandatory=$false)]
                [PSCredential] $sqlCredential = $null
            )

            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }
        
            Write-Host "Remove Network Service User from $DatabaseName"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
            IF EXISTS (SELECT 'X' FROM sysusers WHERE name = 'NT AUTHORITY\NETWORK SERVICE' and isntuser = 1)
              BEGIN DROP USER [NT AUTHORITY\NETWORK SERVICE] END"

            Write-Host "Remove System User from $DatabaseName"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
            IF EXISTS (SELECT 'X' FROM sysusers WHERE name = 'NT AUTHORITY\SYSTEM' and isntuser = 1)
              BEGIN DROP USER [NT AUTHORITY\SYSTEM] END"
        }

        function Check-Entitlements {
            Param (
                [Parameter(Mandatory=$true)]
                [string] $DatabaseName,
                [Parameter(Mandatory=$true)]
                [string] $DatabaseServer,
                [Parameter(Mandatory=$false)]
                [PSCredential] $sqlCredential = $null
            )

            Write-Host "Checking Entitlements"
            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }

            'Membership Entitlement', 'Entitlement Set', 'Entitlement' | % {
                $result = Invoke-Sqlcmd @params -query "USE [$DatabaseName] select count(*) from [dbo].[$_]"
                if (($result) -and ($result.Column1 -eq 0)) {
                    throw "Entitlements are missing in table $_. Add -doNotCheckEntitlements to dismiss this error and create .bacpac files, that cannot be used for Cloud deployments."
                }
            }
        }
        
        function Remove-NavDatabaseSystemTableData {
            Param (
                [Parameter(Mandatory=$true)]
                [string] $DatabaseName,
                [Parameter(Mandatory=$true)]
                [string] $DatabaseServer,
                [Parameter(Mandatory=$false)]
                [PSCredential] $sqlCredential = $null
            )
         
            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }
        
            Write-Host "Remove data from System Tables database $DatabaseName"
            'Server Instance','$ndo$cachesync','$ndo$tenants','Object Tracking' | % {
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[$_]"
            }
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] UPDATE [dbo].[`$ndo`$dbproperty] SET [license] = NULL"
        
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
              IF EXISTS ( SELECT 'X' FROM [sys].[tables] WHERE name = 'Active Session' AND type = 'U' )
                BEGIN Delete from dbo.[Active Session] END" 
            
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
              IF EXISTS ( SELECT 'X' FROM [sys].[tables] WHERE name = 'Session Event' AND type = 'U' )
                BEGIN Delete from dbo.[Session Event] END" 
        
            Remove-NetworkServiceUser -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName -sqlCredential $sqlCredential
        }
        
        function Remove-NavTenantDatabaseUserData {
            Param (        
                [Parameter(Mandatory=$true)]
                [string] $DatabaseName,
                [Parameter(Mandatory=$true)]
                [string] $DatabaseServer,
                [Parameter(Mandatory=$false)]
                [PSCredential] $sqlCredential = $null,
                [switch] $KeepUserData
            )

            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }
        
            if (!($KeepUserData)) {
                Write-Host "Remove data from User table and related tables in $DatabaseName database."
                'Access Control',
                'User Property',
                'User Personalization',
                'User Metadata',
                'User Default Style Sheet',
                'User',
                'User Group Member',
                'User Group Access Control',
                'User Plan' | % {
                    Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[$_]"
                }

                $tables = Invoke-Sqlcmd @params -Query "USE [$DatabaseName] SELECT name FROM sysobjects WHERE (xtype = 'U' ) AND (name LIKE '%User Login')"
                $tables | % {
                    Write-Host "DELETE FROM dbo.[$($_.Name)]"
                    Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[$($_.Name)]"
                }
            }

            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] UPDATE [dbo].[$("$")ndo$("$")tenantproperty] SET [license] = NULL"

            'Tenant License State',
            'Active Session',
            'Session Event' | % {
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[$_]"
            }
        
            Write-Host "Drop triggers from $DatabaseName"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DROP TRIGGER [dbo].[RemoveOnLogoutActiveSession]" 
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DROP TRIGGER [dbo].[DeleteActiveSession]" 
            
            Write-Host "Drop Views from $DatabaseName"
            Invoke-Sqlcmd @Params -Query "USE [$DatabaseName] DROP VIEW IF EXISTS [dbo].[deadlock_report_ring_buffer_view]"
        
            Remove-NetworkServiceUser -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName -sqlCredential $sqlCredential
        }

        function Do-Export {
            Param (        
                [Parameter(Mandatory=$true)]
                [string] $DatabaseName,
                [Parameter(Mandatory=$true)]
                [string] $DatabaseServer,
                [Parameter(Mandatory=$false)]
                [PSCredential] $sqlCredential = $null,
                [Parameter(Mandatory=$true)]
                [string] $targetFile,
                [Parameter(Mandatory=$false)]
                [int] $commandTimeout = 3600,
                [switch] $diagnostics,
                [Parameter(Mandatory=$false)]
                [string[]] $additionalArguments = @()
            )

            Write-Host "Exporting..."
            $arguments = @(
                ('/Action:Export'),
                ('/TargetFile:"'+$targetFile+'"'), 
                ('/SourceDatabaseName:"'+$databaseName+'"'),
                ('/SourceServerName:"'+$databaseServer+'"'),
                ('/OverwriteFiles:True')
                ("/p:CommandTimeout=$commandTimeout")
            )

            if ($diagnostics) {
                $arguments += @('/Diagnostics:True')
            }

            if ($sqlCredential) {
                $arguments += @(
                    ('/SourceUser:"'+$sqlCredential.UserName+'"'),
                    ('/SourcePassword:"'+([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password)))+'"')
                )
            }

            if ($additionalArguments) {
                $arguments += $additionalArguments
            }

            & $sqlPackageExe $arguments
        }

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $multitenant = ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -eq "true")
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value

        $databaseServerInstance = $databaseServer
        if ("$databaseInstance" -ne "") {
            $databaseServerInstance = "$databaseServer\$databaseInstance"
        }

        $sqlPackageExe = Install-DACFx

        if (!(Test-Path $bacpacFolder)) {
            New-Item $bacpacFolder -ItemType Directory | Out-Null
        }
       
        if ($multitenant) {
            $tempAppDatabaseName = "temp$DatabaseName"
            $appBacpacFileName = Join-Path $bacpacFolder "app.bacpac"
            Copy-NavDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -databaseCredentials $sqlCredential -SourceDatabaseName $DatabaseName -DestinationDatabaseName $tempAppDatabaseName
            if (!$doNotCheckEntitlements) {
                Check-Entitlements -DatabaseServer $databaseServerInstance -DatabaseName $tempAppDatabaseName -sqlCredential $sqlCredential
            }
            Remove-NavDatabaseSystemTableData -DatabaseServer $databaseServerInstance -DatabaseName $tempAppDatabaseName -sqlCredential $sqlCredential
            Do-Export -DatabaseServer $databaseServerInstance -DatabaseName $tempAppDatabaseName -sqlCredential $sqlCredential -targetFile $appBacpacFileName -commandTimeout $commandTimeout -diagnostics:$diagnostics -additionalArguments $additionalArguments
            
            $tenant | ForEach-Object {
                $sourceDatabase = $_
                if ("$_" -ne "tenant") {
                    $tenantInfo = Get-NavTenant -ServerInstance $ServerInstance -tenant $_ -ForceRefresh
                    $sourceDatabase = $tenantInfo.DatabaseName
                    if ($tenantInfo.State -ne "Operational") {
                        throw "Tenant $_ is not operational, you might need to synchronize the tenant or run data upgrade"
                    }
                }
                $tempTenantDatabaseName = "tempTenant"
                $tenantBacpacFileName = Join-Path $bacpacFolder "$_.bacpac"
                Copy-NavDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -databaseCredentials $sqlCredential -SourceDatabaseName $sourceDatabase -DestinationDatabaseName $tempTenantDatabaseName
                Remove-NavTenantDatabaseUserData -DatabaseServer $databaseServerInstance -DatabaseName $tempTenantDatabaseName -sqlCredential $sqlCredential
                Do-Export -DatabaseServer $databaseServerInstance -DatabaseName $tempTenantDatabaseName -sqlCredential $sqlCredential -targetFile $tenantBacpacFileName -commandTimeout $commandTimeout -diagnostics:$diagnostics -additionalArguments $additionalArguments
            }
        } else {
            $tempDatabaseName = "temp$DatabaseName"
            $bacpacFileName = Join-Path $bacpacFolder "database.bacpac"
            Copy-NavDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -databaseCredentials $sqlCredential -SourceDatabaseName $DatabaseName -DestinationDatabaseName $tempDatabaseName
            if (!$doNotCheckEntitlements) {
                Check-Entitlements -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential
            }
            Remove-NavDatabaseSystemTableData -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential
            Remove-NavTenantDatabaseUserData -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential
            Do-Export -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential -targetFile $bacpacFileName -commandTimeout $commandTimeout -diagnostics:$diagnostics -additionalArguments $additionalArguments
        }
    } -ArgumentList $sqlCredential, $containerBacpacFolder, $tenant, $commandTimeout, $diagnostics, $additionalArguments, $doNotCheckEntitlements
}
Set-Alias -Name Export-NavContainerDatabasesAsBacpac -Value Export-BcContainerDatabasesAsBacpac
Export-ModuleMember -Function Export-BcContainerDatabasesAsBacpac -Alias Export-NavContainerDatabasesAsBacpac
