<# 
 .Synopsis
  Export databases in a Nav container as .bacpac files
 .Description
  If the Nav Container is multi-tenant, this command will create an app.bacpac and a tenant.bacpac.
  If the Nav Container is single-tenant, this command will create one bacpac file called database.bacpac.
 .Parameter containerName
  Name of the container for which you want to export and convert objects
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter bacpacFolder
  The folder to which the bacpac files are exported (needs to be shared with the container)
 .Parameter tenant
  The tenant database(s) to export, only applies to multi-tenant containers
  Omit to export tenant template, specify default to export the default tenant.
 .Example
  Export-NavContainerDatabasesAsBacpac -containerName test
 .Example
  Export-NavContainerDatabasesAsBacpac -containerName test -bacpacfolder "c:\programdata\navcontainerhelper\extensions\test"
 .Example
  Export-NavContainerDatabasesAsBacpac -containerName test -bacpacfolder "c:\demo" -sqlCredential <sqlCredential>
 .Example
  Export-NavContainerDatabasesAsBacpac -containerName test -tenant default
 .Example
  Export-NavContainerDatabasesAsBacpac -containerName test -tenant @("default","tenant")
#>
function Export-NavContainerDatabasesAsBacpac {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$sqlCredential = $null,
        [Parameter(Mandatory=$false)]
        [string]$bacpacFolder = "",
        [Parameter(Mandatory=$false)]
        [string[]]$tenant = @("tenant")
    )
    
    $genericTag = Get-NavContainerGenericTag -containerOrImageName $containerName
    if ([System.Version]$genericTag -lt [System.Version]"0.0.4.5") {
        throw "Export-DatabasesAsBacpac is not supported in images with generic tag prior to 0.0.4.5"
    }

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    if ("$bacpacFolder" -eq "") {
        $bacpacFolder = $containerFolder
    }
    $containerBacpacFolder = Get-NavContainerPath -containerName $containerName -path $bacpacFolder -throw

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param([System.Management.Automation.PSCredential]$sqlCredential, $bacpacFolder, $tenant)
    
        function Install-DACFx
        {
            $DacFxMsi = Join-Path $env:TEMP "DacFramework.msi"
            $sqlpakcageExe = "C:\Program Files\Microsoft SQL Server\140\DAC\bin\sqlpackage.exe"
            if (!(Test-Path $sqlpakcageExe -PathType Leaf)) {
                Write-Host "Downloading DacFx 17.3 GA"
                (New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/3/7/F/37F3C5CE-E96B-41AC-B361-27735365AA16/EN/x64/DacFramework.msi",$DacFxMsi)
                Write-Host "Installing DacFx 17.3 GA"
                Start-process -FilePath $DacFxMsi -argumentList "/qn" -Wait
                Remove-Item -Path $DacFxMsi
            }
            $sqlpakcageExe 
        }
        
        function Remove-NetworkServiceUser
        (
            [Parameter(Mandatory=$true)]
            [string]$DatabaseName,
            [Parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            [Parameter(Mandatory=$false)]
            [System.Management.Automation.PSCredential]$sqlCredential = $null
        )
        {
            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }
        
            Write-Host "Remove Network Service User from $DatabaseName"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
            IF EXISTS (SELECT 'X' FROM sysusers WHERE name = 'NT AUTHORITY\NETWORK SERVICE' and isntuser = 1)
              BEGIN DROP USER [NT AUTHORITY\NETWORK SERVICE] END"
        }
        
        function Remove-NavDatabaseSystemTableData
        (
            [Parameter(Mandatory=$true)]
            [string]$DatabaseName,
            [Parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            [Parameter(Mandatory=$false)]
            [System.Management.Automation.PSCredential]$sqlCredential = $null
        )
        {
            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }
        
            Write-Host "Remove data from System Tables database $DatabaseName"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[Server Instance]" 
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[$("$")ndo$("$")cachesync]"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[$("$")ndo$("$")tenants]"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] UPDATE [dbo].[$("$")ndo$("$")dbproperty] SET [license] = NULL"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[Object Tracking]" 
        
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
              IF EXISTS ( SELECT 'X' FROM [sys].[tables] WHERE name = 'Active Session' AND type = 'U' )
                BEGIN Delete from dbo.[Active Session] END" 
            
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName]
              IF EXISTS ( SELECT 'X' FROM [sys].[tables] WHERE name = 'Session Event' AND type = 'U' )
                BEGIN Delete from dbo.[Session Event] END" 
        
            Remove-NetworkServiceUser -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName -sqlCredential $sqlCredential
        }
        
        function Remove-NavTenantDatabaseUserData
        (        
            [Parameter(Mandatory=$true)]
            [string]$DatabaseName,
            [Parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            [Parameter(Mandatory=$false)]
            [System.Management.Automation.PSCredential]$sqlCredential = $null,
            [Parameter(Mandatory=$false)]
            [switch]$KeepUserData
        )
        {
            $params = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = $databaseServer }
            if ($sqlCredential) {
                $params += @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
            }
        
            Write-Host "Remove data from User table and related tables in $DatabaseName database."
            if (!($KeepUserData)) {
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[Access Control]" 
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[User Property]" 
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[User Personalization]" 
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[User Metadata]" 
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[User Default Style Sheet]" 
                Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[User]" 
            }
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] UPDATE [dbo].[$("$")ndo$("$")tenantproperty] SET [license] = NULL"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[Tenant License State]" 
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[Active Session]" 
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DELETE FROM dbo.[Session Event]" 
        
            Write-Host "Drop triggers from $DatabaseName"
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DROP TRIGGER [dbo].[RemoveOnLogoutActiveSession]" 
            Invoke-Sqlcmd @params -Query "USE [$DatabaseName] DROP TRIGGER [dbo].[DeleteActiveSession]" 
        
            Remove-NetworkServiceUser -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName -sqlCredential $sqlCredential
        }

        function Do-Export
        (        
            [Parameter(Mandatory=$true)]
            [string]$DatabaseName,
            [Parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            [Parameter(Mandatory=$false)]
            [System.Management.Automation.PSCredential]$sqlCredential = $null,
            [Parameter(Mandatory=$true)]
            [string]$targetFile
        )
        {
            $arguments = @(
                ('/Action:Export'), 
                ('/TargetFile:"'+$targetFile+'"'), 
                ('/SourceDatabaseName:"'+$databaseName+'"'),
                ('/SourceServerName:"'+$databaseServer+'"'),
                ('/OverwriteFiles:True')
            )

            if ($sqlCredential) {
                $arguments += @(
                    ('/SourceUser:"'+$sqlCredential.UserName+'"'),
                    ('/SourcePassword:"'+([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password)))+'"')
                )
            }

            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = $sqlPackageExe
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $pinfo.Arguments = $arguments
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null

            while (!$p.HasExited){
                $line = $p.StandardOutput.ReadLine()
                Write-Host $line
            }
            $line = $p.StandardOutput.ReadToEnd()
            Write-Host $line
            $err = $p.StandardError.ReadToEnd()
            if ($err) {
                Write-Error $err
            }
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
       
        if ($multitenant) {
            $tempAppDatabaseName = "temp$DatabaseName"
            $appBacpacFileName = Join-Path $bacpacFolder "app.bacpac"
            Copy-NavDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -databaseCredentials $sqlCredential -SourceDatabaseName $DatabaseName -DestinationDatabaseName $tempAppDatabaseName
            Remove-NavDatabaseSystemTableData -DatabaseServer $databaseServerInstance -DatabaseName $tempAppDatabaseName -sqlCredential $sqlCredential
            Do-Export -DatabaseServer $databaseServerInstance -DatabaseName $tempAppDatabaseName -sqlCredential $sqlCredential -targetFile $appBacpacFileName
            
            $tenant | ForEach-Object {
                $tempTenantDatabaseName = "tempTenant"
                $tenantBacpacFileName = Join-Path $bacpacFolder "$_.bacpac"
                Copy-NavDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -databaseCredentials $sqlCredential -SourceDatabaseName $_ -DestinationDatabaseName $tempTenantDatabaseName
                Remove-NavTenantDatabaseUserData -DatabaseServer $databaseServerInstance -DatabaseName $tempTenantDatabaseName -sqlCredential $sqlCredential
                Do-Export -DatabaseServer $databaseServerInstance -DatabaseName $tempTenantDatabaseName -sqlCredential $sqlCredential -targetFile $tenantBacpacFileName
            }
        } else {
            $tempDatabaseName = "temp$DatabaseName"
            $bacpacFileName = Join-Path $bacpacFolder "database.bacpac"
            Copy-NavDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -databaseCredentials $sqlCredential -SourceDatabaseName $DatabaseName -DestinationDatabaseName $tempDatabaseName
            Remove-NavDatabaseSystemTableData -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential
            Remove-NavTenantDatabaseUserData -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential
            Do-Export -DatabaseServer $databaseServerInstance -DatabaseName $tempDatabaseName -sqlCredential $sqlCredential -targetFile $bacpacFileName
        }
    } -ArgumentList $sqlCredential, $containerBacpacFolder, $tenant
}
Export-ModuleMember Export-NavContainerDatabasesAsBacpac

