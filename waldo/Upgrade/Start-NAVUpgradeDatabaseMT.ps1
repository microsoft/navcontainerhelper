function Start-NAVUpgradeDatabaseMT
{
    <#
        .SYNOPSIS
        Upgrades a database in the Multi Tenancy-way: by creating an app-db, mounting the old db as a tenant, an performing the data-upgrade like that (avoiding the classic database conversion)
    #>
    [CmdLetBinding()]
    param(
        [String] $Name,
        [String] $ModifiedDatabaseBackupLocation,
        [String] $UpgradeCodeunitsFullPath,
        [String] $TargetServerInstance,
        [String] $LicenseFile,
        [String] $TextFileFolder,
        [String] $WorkingFolder
        
    )
    
    $MultiTenantServerInstance =
        New-NAVUpgradeApplicationDB `
            -TargetServerInstance $TargetServerInstance `
            -LicenseFile $NAVLicense `
            -TextFileFolder $FilteredMergeResultFolder `
            -WorkingFolder $WorkingFolder `
            -Name $UpgradeName `
            -ErrorAction Stop
    
    $TenantName = "$($Name)_Tenant"
    $MultiTenantServerInstanceObject = Get-NAVServerInstance4 -ServerInstance $MultiTenantServerInstance.ServerInstance -ErrorAction Stop

    #Prepare Tenant with data
    write-host -ForegroundColor Green -Object "Preparing $TenantName ..."
    $null =
        Restore-SQLBackupFile `
            -BackupFile $ModifiedDatabaseBackupLocation `
            -DatabaseName $TenantName        
    $null =
        Remove-NAVApplication `
            -DatabaseName $TenantName `
            -Force
    
    #mount the data to the app
    write-host -ForegroundColor Green -Object "Mount $TenantName to the app"
    $null =
        Mount-NAVTenant `
            -ServerInstance $MultiTenantServerInstanceObject.ServerInstance `
            -DatabaseName $TenantName `
            -Id 'Default' `
            -Force
    
    if ($UpgradeCodeunitsFullPath){        
        write-host -ForegroundColor Green -Object 'Import Upgrade Codeunits'
        $null =    
            Import-NAVApplicationObject `
                -Path $UpgradeCodeunitsFullPath `
                -DatabaseName $MultiTenantServerInstanceObject.DatabaseName `
                -DatabaseServer $MultiTenantServerInstanceObject.DatabaseServer `
                -Confirm:$false `
                -ErrorAction Continue `
                -ImportAction Overwrite `
                -NavServerInstance $MultiTenantServerInstanceObject.ServerInstance `
                -NavServerName ([net.dns]::gethostname()) `
                -SynchronizeSchemaChanges No
    }

    write-host -ForegroundColor Green -Object 'Syncing Tenant'
    $null =
        Sync-NAVTenant `
            -ServerInstance $MultiTenantServerInstanceObject.ServerInstance `
            -Tenant 'Default' `
            -Force
    
    #Start Dataupgrade
    Write-Host 'Starting Data Upgrade' -ForegroundColor Green
    Start-NAVDataUpgrade `
        -ServerInstance $MultiTenantServerInstanceObject.ServerInstance `        -Tenant 'Default' `        -SkipCompanyInitialization `        -ContinueOnError `        -Force
    
    $Stop = $false
    while (!$Stop){
        $NAVDataUpgradeStatus = 
            Get-NAVDataUpgrade `                -ServerInstance $MultiTenantServerInstanceObject.ServerInstance `                -Tenant 'Default'
        Write-Host "$($NAVDataUpgradeStatus.State) -- $($NAVDataUpgradeStatus.Progress)" -ForeGroundColor Gray
        if ($NAVDataUpgradeStatus.State -ne 'InProgress') {
            $Stop = $true
        }
        Start-Sleep 2
    }
    
    write-host "Data upgrade status: $($NAVDataUpgradeStatus.State)" -ForegroundColor Green
    
    #Remove Upgrade Codeunits
    if ($UpgradeCodeunitsFullPath){        
        write-host -ForegroundColor Green -Object 'Deleting Upgrade Codeunits'
        $null =
            Delete-NAVApplicationObject `
                -DatabaseName $MultiTenantServerInstanceObject.DatabaseName `
                -DatabaseServer $MultiTenantServerInstanceObject.DatabaseServer `
                -Confirm:$false `
                -ErrorAction Continue `
                -NavServerInstance $MultiTenantServerInstanceObject.ServerInstance `
                -NavServerName ([net.dns]::gethostname()) `
                -Filter 'Version List=*UPG*' `
                -SynchronizeSchemaChanges Force
    }
    
    write-host -ForegroundColor Green -Object 'Converting to Single Tenant'
    $null =
        Dismount-NAVTenant `
            -ServerInstance $MultiTenantServerInstanceObject.ServerInstance `
            -Tenant 'Default' `
            -Force    
    $null =
        Export-NAVApplication `
            -DatabaseName $MultiTenantServerInstanceObject.DatabaseName `            -DestinationDatabaseName $TenantName `
            -Force `
            -ErrorAction SilentlyContinue
    
    write-host -ForegroundColor Green -Object "Backup $TenantName to Result.bak"
    $ResultBackup =
        Backup-SQLDatabaseToFile `
            -DatabaseName $TenantName `
            -BackupFile 'Result.bak'
            
    #Remove Temp environments
    write-host -ForegroundColor Green -Object "Removing Temp-environment $TenantName and $($MultiTenantServerInstanceObject.ServerInstance)"
    $null = Drop-SQLDatabaseIfExists -Databasename $TenantName 
    $null = Remove-NAVEnvironment -ServerInstance $MultiTenantServerInstanceObject.ServerInstance -Force
    
    write-host -ForegroundColor Green -Object "Create Result-environment '$Name'"
    $null =
        New-NAVEnvironment `
            -ServerInstance $Name `
            -BackupFile $ResultBackup `
            -EnablePortSharing `
            -StartWindowsClient

    $null = Move-Item -Path $ResultBackup -Destination (join-path $WorkingFolder 'Result.bak') -Force

    return (Get-NAVServerInstance $Name)
    }
    


<#

$SQLQuery = " 
IF OBJECT_ID (N'Object', N'U') IS NOT NULL 
   SELECT 1 AS Count ELSE SELECT 0 AS res;
"
$Result = Invoke-SQL -SQLCommand $SQLQuery -DatabaseName 'ResultTenant'
$Result.Count

Remove-NAVApplication `
    -DatabaseName 'ResultTenant' `
    -Force

Remove-NAVApplication -DatabaseName ResultTenant
#>