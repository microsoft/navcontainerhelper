<# 
 .Synopsis
  Backup databases in a Nav container as .bak files
 .Description
  If the Nav Container is multi-tenant, this command will create an app.bak and a tenant.bak (or multiple tenant.bak files)
  If the Nav Container is single-tenant, this command will create one .bak file called database.bak.
 .Parameter containerName
  Name of the container for which you want to export and convert objects
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication.
 .Parameter Folder
  The folder to which the bak files are exported (needs to be shared with the container)
 .Parameter tenant
  The tenant database(s) to export, only applies to multi-tenant containers
  Omit to export tenant template, specify default to export the default tenant.
 .Example
  Backup-NavContainerDatabases -containerName test
 .Example
  Backup-NavContainerDatabases -containerName test -bakfolder "c:\programdata\navcontainerhelper\extensions\test"
 .Example
  Backup-NavContainerDatabases -containerName test -bakfolder "c:\demo" -sqlCredential <sqlCredential>
 .Example
  Backup-NavContainerDatabases -containerName test -tenant default
 .Example
  Backup-NavContainerDatabases -containerName test -tenant @("default","tenant")
#>
function Backup-NavContainerDatabases {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$sqlCredential = $null,
        [Parameter(Mandatory=$false)]
        [string]$bakFolder = "",
        [Parameter(Mandatory=$false)]
        [string[]]$tenant = @("tenant")
    )
    
    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential -doNotAskForCredential

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    if ("$bakFolder" -eq "") {
        $bakFolder = $containerFolder
    }
    $containerBakFolder = Get-NavContainerPath -containerName $containerName -path $bakFolder -throw

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param([System.Management.Automation.PSCredential]$sqlCredential, $bakFolder, $tenant)
       
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

        if ($multitenant) {
            Backup-SqlDatabase -ServerInstance $databaseServerInstance -database $DatabaseName -BackupFile Join-Path $bacpacFolder "app.bak"
            $tenant | ForEach-Object {
                Backup-SqlDatabase -ServerInstance $databaseServerInstance -database $_ -BackupFile (Join-Path $bakFolder "$_.bak")
            }
        } else {
            Backup-SqlDatabase -ServerInstance $databaseServerInstance -database $DatabaseName -BackupFile (Join-Path $bakFolder "database.bak")
        }
    } -ArgumentList $sqlCredential, $containerbakFolder, $tenant
}
Export-ModuleMember Backup-NavContainerDatabases

