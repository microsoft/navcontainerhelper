<# 
 .Synopsis
  Backup databases in a NAV/BC Container as .bak files
 .Description
  If the Container is multi-tenant, this command will create an app.bak and a number of tenant .bak files
  If the Container is single-tenant, this command will create one .bak file called database.bak.
 .Parameter containerName
  Name of the container in which you want to backup databases
 .Parameter bakFolder
  The folder to which the .bak files are exported (needs to be shared with the container)
 .Parameter tenant
  The tenant database(s) to export, only applies to multi-tenant containers. Omit to export all tenants.
 .Parameter databaseCredential
  database credentials if using an external sQL Server
 .Parameter compress
  Compress the database backup. SQL Express doesn't support compression.
 .Example
  Backup-BcContainerDatabases -containerName test
 .Example
  Backup-BcContainerDatabases -containerName test -bakfolder "c:\programdata\bccontainerhelper\extensions\test"
 .Example
  Backup-BcContainerDatabases -containerName test -tenant @("default")
#>
function Backup-BcContainerDatabases {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [string] $bakFolder = "",
        [string[]] $tenant,
        [pscredential] $databasecredential,
        [switch] $compress
    )

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    if ("$bakFolder" -eq "") {
        $bakFolder = $containerFolder
    }
    elseif (!$bakFolder.Contains('\')) {
        $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
        if ((Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { $env:IsBcSandbox }) -eq "Y") {
            $folderPrefix = "sandbox"
        }
        else {
            $folderPrefix = "onprem"
        }
        $bakFolder = Join-Path $containerHelperFolder "$folderPrefix-$NavVersion-bakFolders\$bakFolder"
    }
    $containerBakFolder = Get-BcContainerPath -containerName $containerName -path $bakFolder -throw

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($bakFolder, $tenant, $databasecredential, $compress)
       
        function Backup {
            Param (
                [string] $serverInstance,
                [string] $database,
                [string] $bakFolder,
                [string] $bakName,
                [pscredential] $databaseCredential,
                [switch] $compress
            )
            $bakFile = Join-Path $bakFolder "$bakName.bak"
            if (Test-Path $bakFile) {
                Remove-Item -Path $bakFile -Force
            }
            Write-Host "Backing up $database to $bakFile"
            $params = @{}
            if ($compress) { $params += @{ "CompressionOption" = "On" } }
            if ($databaseCredential) { $params += @{ "credential" = $databaseCredential } }
            Backup-SqlDatabase -ServerInstance $serverInstance -database $database -BackupFile $bakFile @params
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

        if (!(Test-Path $bakFolder)) {
            New-Item $bakFolder -ItemType Directory | Out-Null
        }

        if ($multitenant) {
            if (!($tenant)) {
                $tenant = @(get-navtenant $serverInstance | % { $_.Id }) + "tenant"
            }
            Backup -ServerInstance $databaseServerInstance -database $DatabaseName -bakFolder $bakFolder -bakName "app" -databasecredential $databasecredential -compress:$compress
            $tenant | ForEach-Object {
                $tenantInfo = Get-NAVTenant -ServerInstance $serverInstance $_ -ErrorAction SilentlyContinue
                if ($tenantInfo) {
                    $dbName = $tenantInfo.DatabaseName
                }
                else {
                    $tenantInfo = Get-NAVTenant -ServerInstance $serverInstance default -ErrorAction SilentlyContinue
                    if ($tenantInfo) {
                        $dbName = $tenantInfo.DatabaseName.replace('default',$_)
                    }
                    else {
                        $dbName = $_
                    }
                }
                Backup -ServerInstance $databaseServerInstance -database $dbName -bakFolder $bakFolder -bakName $_ -databasecredential $databasecredential -compress:$compress
            }
        } else {
            Backup -ServerInstance $databaseServerInstance -database $DatabaseName -bakFolder $bakFolder -bakName "database" -databasecredential $databasecredential -compress:$compress
        }
    } -ArgumentList $containerbakFolder, $tenant, $databasecredential, $compress
}
Set-Alias -Name Backup-NavContainerDatabases -Value Backup-BcContainerDatabases
Export-ModuleMember -Function Backup-BcContainerDatabases -Alias Backup-NavContainerDatabases
