function Backup-SQLDatabaseToFile
{
    <#
    .Synopsis
       Backup a SQL Database to a File
    .DESCRIPTION
       Working with SQL Backups works much faster than working with NAVDataBackup.  Easily working with SQL Backups can termendously make you more effective
    .NOTES
       Output is a System.IO.DirectoryInfo (like Get-Item)
    .PREREQUISITES
   
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false)]
        [String] $DatabaseServer = '.',
        
        [Parameter(Mandatory=$false)]
        [String] $DatabaseInstance,
        
        [Parameter(Mandatory=$true)]
        [String] $DatabaseName,
        
        [Parameter(Mandatory=$false)]
        [String] $BackupFile = "$DatabaseName.bak",

        [Parameter(Mandatory=$false)]
        [String] $TimeOut = 30

    )
    
    import-module 'sqlps' -DisableNameChecking

    $CurrentLocation = Get-Location
    $null = import-module SQLPS -DisableNameChecking -WarningAction SilentlyContinue
    $null = Set-Location $CurrentLocation	

    if ([String]::IsNullOrEmpty($DatabaseInstance)){
        $DatabaseServerInstance = 'MSSQLSERVER'
    } else {
        $DatabaseServerInstance = $DatabaseInstance
    }

    $BaseReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $DatabaseServer)
    $RegKey  = $BaseReg.OpenSubKey('SOFTWARE\\Microsoft\\Microsoft SQL Server\\Instance Names\\SQL')
    $SQLinstancename = $RegKey.GetValue($DatabaseServerInstance)
    $RegKey  = $BaseReg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\$SQLInstancename\\MSSQLServer")
    $Backuplocation = $RegKey.GetValue('BackupDirectory')
     
    $BackupFileFullPath = Join-Path $Backuplocation $BackupFile
    $SQLString = "BACKUP DATABASE [$DatabaseName] TO  DISK = N'$BackupFileFullPath' WITH  COPY_ONLY, NOFORMAT, INIT,  NAME = N'NAVAPP_QA_MT-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10"
    
    write-Host -ForegroundColor Green "Backing up database $Database ..."
    write-host -ForegroundColor gray $SQLString
    
    Invoke-Sqlcmd -Query $SQLString -ServerInstance "$DatabaseServer\$DatabaseInstance" -QueryTimeout $TimeOut -Database 'master'

    Get-Item $BackupFileFullPath
}

