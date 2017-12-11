function Start-NAVUpgradeDatabase
{
    <#
        .SYNOPSIS
        Upgrades a database the classic way: applies a fob-file on a converted database
    #>
    [CmdLetBinding()]
    param(       
        [String] $Name,   
        [String] $DatabaseBackupFile,
        [String] $ResultObjectFile,
        [String] $WorkingFolder,
        [String] $LicenseFile,
        [String] $UpgradeToolkit,
        #[Object[]] $DeletedObjects,
        [ValidateSet('CheckOnly','ForceSync','Sync')]
        [String] $SyncMode='Sync',
        [ValidateSet('Overwrite','Use')]
        [String] $IfResultDBExists='Overwrite',
        [Switch] $CreateBackup,
        [ValidateSet('Parallel', 'Serial')]
        [String] $FunctionExecutionMode = 'Parallel'
    )
    
    #Creating Workspace
    $LogFolder = join-path $workingfolder 'Log_NAVUpgradeDatabase'
    if(Test-Path $LogFolder){Remove-Item $LogFolder -Force -Recurse}
    $LogDataconversion = Join-path $Logfolder '01_DatabaseConversion'
    $LogDeleteObjects  = Join-path $Logfolder '02_DeleteObjects'
    $LogImportObjects  = Join-path $Logfolder '03_ImportObjects'
    $LogCompileObjects = Join-path $Logfolder '04_CompileObjects'
    $LogExportObjects  = Join-path $Logfolder '05_ExportObjects'
    
    if (!$name) {
        $SandboxServerInstance = Get-SQLBackupDatabaseName -Backupfile $DatabaseBackupFile -ErrorAction Stop
    } else {
        $SandboxServerInstance = $Name
    }

    #Create database in new version
    Write-Host 'Restore modified backup and create as instance' -ForegroundColor Green
    
    $Exists = Get-NAVServerInstance $SandboxServerInstance
    if ($Exists) {   
        if ($IfResultDBExists -eq 'Overwrite') {    
            Remove-NAVEnvironment -ServerInstance $SandboxServerInstance -ErrorAction Stop
            New-NAVEnvironment -ServerInstance $SandboxServerInstance -BackupFile $DatabaseBackupFile -EnablePortSharing -ErrorVariable $ErrorNewNAVEnvironment -ErrorAction SilentlyContinue
        } else {
            Write-Warning "ServerInstance $SandboxServerInstance already exists.  This script is re-using it."
        }
    } else {
        New-NAVEnvironment -ServerInstance $SandboxServerInstance -BackupFile $DatabaseBackupFile -EnablePortSharing -ErrorVariable $ErrorNewNAVEnvironment -ErrorAction SilentlyContinue
    }
    
    if ($ErrorNewNAVEnvironment) {
        if (!($ErrorNewNAVEnvironment -match 'failed to reach status ''Running''')){
            write-error $ErrorNewNAVEnvironment
            break
        }
    }
    
    #Make Admin user DB-Owner
    $CurrentUser = [environment]::UserDomainName + '\' + [Environment]::UserName
    Invoke-SQL -DatabaseName $SandboxServerInstance -SQLCommand "CREATE USER [$CurrentUser] FOR LOGIN [$CurrentUser]" -ErrorAction SilentlyContinue
    Invoke-SQL -DatabaseName $SandboxServerInstance -SQLCommand "ALTER ROLE [db_owner] ADD MEMBER [$CurrentUser]" -ErrorAction SilentlyContinue

    #Import NAV LIcense on server-level 
    Write-Host "Import NAV license in $SandboxServerInstance" -ForegroundColor Green   
    Import-NAVServerLicenseToDatabase -LicenseFile $LicenseFile -ServerInstance $SandboxServerInstance -Scope Database
    
    #Unlock objects
    write-host 'Unlock all objects' -ForegroundColor Green
    Unlock-NAVApplicationObjects -ServerInstance $SandboxServerInstance
   
    #Drop ReVision Triggers
    Invoke-SQL -DatabaseName $SandboxServerInstance -SQLCommand 'DISABLE TRIGGER [dbo].[REVISION_UPDATE] ON [dbo].[Object]' -ErrorAction silentlyContinue
    Invoke-SQL -DatabaseName $SandboxServerInstance -SQLCommand 'DISABLE TRIGGER [dbo].[REVISION_INSERT] ON [dbo].[Object]' -ErrorAction silentlyContinue
    Invoke-SQL -DatabaseName $SandboxServerInstance -SQLCommand 'DISABLE TRIGGER [dbo].[REVISION_DELETE] ON [dbo].[Object]' -ErrorAction silentlyContinue

    #Convert DB
    Write-Host 'Converting Database' -ForegroundColor Green
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    Invoke-NAVDatabaseConversion -DatabaseName $SandboxServerInstance -LogPath $LogDataconversion -ErrorAction stop    
    Invoke-SQL -DatabaseName $SandboxServerInstance -SQLCommand "ALTER DATABASE [$SandboxServerInstance] SET  MULTI_USER WITH NO_WAIT"
    
    #Start NST
    Write-Host "Start NST $SandboxServerInstance" -ForegroundColor Green
    Set-NAVServerInstance -Start -ServerInstance $SandboxServerInstance
    
    #Compile System Tables
    Sync-NAVTenant -ServerInstance $SandboxServerInstance -Mode Sync -Force 
    Compile-NAVApplicationObject2 -ServerInstance $SandboxServerInstance -SynchronizeSchemaChanges Yes -Filter 'Id=2000000000..' -LogPath $LogCompileObjects -Recompile

    #Add my user to the environment
    Write-Host 'Add current user to environment' -ForegroundColor Green
    Add-NAVEnvironmentCurrentUser -ServerInstance $SandboxServerInstance -ErrorAction Stop

    #Import NAV LIcense
    Write-Host "Import NAV license in $SandboxServerInstance" -ForegroundColor Green
    Get-NAVServerInstance -ServerInstance $SandboxServerInstance | Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -WarningAction SilentlyContinue
    #Get-NAVServerInstance -Restart -ServerInstance $SandboxServerInstance
    
    #Delete All except tables
    Write-Host 'Deleting all objects except tables' -ForegroundColor Green
    Delete-NAVApplicationObject `
        -DatabaseName $SandboxServerInstance `
        -LogPath $LogDeleteObjects `
        -SynchronizeSchemaChanges Force `
        -NavServerName ([net.dns]::GetHostName()) `
        -NavServerInstance $SandboxServerInstance `
        -filter 'Type=<>Table' `
        -Confirm:$false  
    

    #Delete Tables without synch
    Write-Host 'Deleting tables without synch' -ForegroundColor Green
    Delete-NAVApplicationObject `
        -DatabaseName $SandboxServerInstance `
        -LogPath $LogDeleteObjects `
        -SynchronizeSchemaChanges No `
        -NavServerName ([net.dns]::GetHostName()) `
        -NavServerInstance $SandboxServerInstance `
        -Confirm:$false `
        -Filter 'Id=<2000000000'   

   
    #Delete tables
    <#
    Write-Host 'Deleting Tables if necessary' -ForegroundColor Green
    $DeletedObjects | where ObjectType -eq 'Table' | foreach {
        Write-Host "  Type=$($_.ObjectType);Id=$($_.Id)" -ForegroundColor Gray
        Delete-NAVApplicationObject `
            -DatabaseName $SandboxServerInstance `
            -LogPath $LogDeleteObjects `
            -SynchronizeSchemaChanges Force `
            -NavServerName ([net.dns]::GetHostName()) `
            -NavServerInstance $SandboxServerInstance `
            -filter "Type=$($_.ObjectType);Id=$($_.Id)" `
            -Confirm:$false
    }
    #>
    
    #Import Fob
    Write-Host "Import $ResultObjectFile" -ForegroundColor Green
    $ResultObjectFile = get-item $ResultObjectFile -ErrorAction Stop
    Import-NAVApplicationObject `
        -DatabaseName $SandboxServerInstance `
        -Path $ResultObjectFile `
        -LogPath $LogImportObjects `
        -SynchronizeSchemaChanges No `
        -ImportAction Overwrite `
        -NavServerName ([net.dns]::GetHostName()) `
        -NavServerInstance $SandboxServerInstance `
        -confirm:$false 
    
    #Import Upgrade Toolkit
    if ($UpgradeToolkit){
        Write-Host 'Import Upgrade Toolkit' -ForegroundColor Green
        $UpgradeToolkitFile = get-item $UpgradeToolkit -ErrorAction Stop
        Import-NAVApplicationObject `
            -DatabaseName $SandboxServerInstance `
            -Path $UpgradeToolkit `
            -LogPath $LogImportObjects `
            -NavServerName ([net.dns]::GetHostName()) `
            -NavServerInstance $SandboxServerInstance `
            -confirm:$false `
            -ImportAction Overwrite
    }

    #Sync
    Write-Host 'Performing Sync-NAVTenant' -ForegroundColor Green
    Sync-NAVTenant `
        -ServerInstance $SandboxServerInstance `
        -Tenant Default `
        -Mode $SyncMode `
        -Force `
        -ErrorAction Stop

    #Start Dataupgrade
    if ($UpgradeToolkit){

        Write-Host 'Starting Data Upgrade' -ForegroundColor Green
        Start-NAVDataUpgrade -ServerInstance $SandboxServerInstance -SkipCompanyInitialization -ContinueOnError -Force -FunctionExecutionMode $FunctionExecutionMode 
    
        Get-NAVDataUpgradeContinuous -ServerInstance $SandboxServerInstance
    }

    #Start RTC
    Start-NAVWindowsClient -ServerInstance $SandboxServerInstance -ServerName ([net.dns]::GetHostName())
    
    #BackupDB
    if ($CreateBackup){
        $ResultDBBackupfile = Backup-NAVDatabase -ServerInstance $SandboxServerInstance
        $ResultDBBackupfile = get-item $ResultDBBackupfile
        $ResultDBBackupfile = move-item -Path $ResultDBBackupfile.FullName -Destination (join-path $WorkingFolder $ResultDBBackupfile.Name) -PassThru -Force
    
        Write-Host "Backup created on $($ResultDBBackupfile.Directory)" -ForegroundColor Green 
    }

    Get-NAVServerInstance -ServerInstance $SandboxServerInstance
}

