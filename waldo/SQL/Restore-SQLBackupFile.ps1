function Restore-SQLBackupFile
{
    <#
    .Synopsis
       Restore a SQL Database to a File
    .DESCRIPTION
       Working with SQL Backups works much faster than working with NAVDataBackup.  Easily working with SQL Backups can termendously make you more effective
    .NOTES
       No Return value
    .PREREQUISITES
   
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $BackupFile,
        [Parameter(Mandatory=$false)]
        [String] $DatabaseServer = '.',
        [Parameter(Mandatory=$false)]
        [String] $DatabaseInstance = '',
        [Parameter(Mandatory=$true)]
        [String] $DatabaseName,
        [Parameter(Mandatory=$false)]
        [String] $DatabaseDataPath = '',
        [Parameter(Mandatory=$false, Position=2)]
        [String] $DatabaseLogPath = '',
        [Parameter(Mandatory=$false)]
        [String] $TimeOut = 30
    )
    
    import-module 'sqlps' -DisableNameChecking

    if ([String]::IsNullOrEmpty($DatabaseDataPath)){
        $SQLString = "SELECT [Default Data Path] = SERVERPROPERTY('InstanceDefaultDataPath')"
        $DatabaseDataPath = (invoke-sql -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -sqlCommand $SQLString)."Default Data Path"
    }
    if ([String]::IsNullOrEmpty($DatabaseLogPath)){
        $SQLString = "SELECT [Default Log Path] = SERVERPROPERTY('InstanceDefaultLogPath')"
        $DatabaseLogPath = (invoke-sql -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -sqlCommand $SQLString)."Default Log Path"
    }
    $SQLString = "RESTORE FILELISTONLY FROM DISK=N'$BackupFile'"
    
    $DatabaseFileList = Invoke-sql -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -sqlCommand $SQLString
    
    $RestoreSQLString = "RESTORE DATABASE [$DatabaseName] FROM DISK = N'$BackupFile' WITH FILE = 1,
    "
    foreach ($File in $DatabaseFileList){
        if ($File.Type -eq 'L') {
            $DatabaseFile = (join-path $DatabaseLogPath ($DatabaseName + "_$($File.FileId)" + [io.path]::GetExtension($File.PhysicalName)) ) 
        } else {
            $DatabaseFile = (join-path $DatabaseDataPath ($DatabaseName + "_$($File.FileId)"  + [io.path]::GetExtension($File.PhysicalName)) ) 
        }
        $RestoreSQLString += "MOVE N'$($File.LogicalName)' TO N'$($DatabaseFile)',
        "
    }
    $RestoreSQLString += 'NOUNLOAD, REPLACE, STATS = 5'

    write-Host -ForegroundColor Green "Restoring database $DatabaseName"
    write-host -ForegroundColor gray $RestoreSQLString
        
    $null = Invoke-Sqlcmd -Query $RestoreSQLString -ServerInstance "$DatabaseServer\$DatabaseInstance" -QueryTimeout $TimeOut -Database 'master' 
        
}

