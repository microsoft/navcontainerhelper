function New-NAVEnvironment {
    [CmdletBinding()]
    param(
        [String]$ServerInstance,
        [String]$DatabaseServer='.',
        [String]$DatabaseInstance='',
        [String]$Databasename='',
        [String]$BackupFile,
        [switch]$EnablePortSharing,
        [Switch]$StartWindowsClient,
        [String]$LicenseFile,
        [int]$ManagementServicesPort=7045,
        [int]$ClientServicesPort=7046,
        [Switch]$CreateWebServerInstance
    )

    if ([String]::IsNullOrEmpty($Databasename)){
        $Databasename = $ServerInstance
    }
    
    $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $ServerInstance
    if ($ServerInstanceExists) {
        Write-Error "Server Instance $ServerInstance already exists!"
        break
    }

    write-Host -ForegroundColor Green "Restoring Backup $BackupFile to $Databasename"
    Restore-SQLBackupFile -BackupFile $BackupFile -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName $Databasename -ErrorAction Stop -TimeOut 0

    write-Host -ForegroundColor Green "Creating ServerInstance $ServerInstance"
    $Object = New-NAVServerInstance `
            -ServerInstance $ServerInstance `
            -DatabaseServer $DatabaseServer `
            -DatabaseInstance $DatabaseInstance `
            -ManagementServicesPort $ManagementServicesPort `
            -ClientServicesPort $ClientServicesPort `
            -DatabaseName $Databasename          

    $ServerInstanceObject = Get-NAVServerInstance4 -ServerInstance $ServerInstance
    write-Host -ForegroundColor Green "Make ServiceAccount $($ServerInstanceObject.ServiceAccount) DBOwner"
    <#$SQLCommand = 
        "IF NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = '$($ServerInstanceObject.ServiceAccount)')
            BEGIN
                CREATE USER [$($ServerInstanceObject.ServiceAccount)] FOR LOGIN [$($ServerInstanceObject.ServiceAccount)]                    
            END"#>
    try{
        $SQLCommand = "CREATE USER [$($ServerInstanceObject.ServiceAccount)] FOR LOGIN [$($ServerInstanceObject.ServiceAccount)]"        
        Invoke-SQL `
            -DatabaseServer $ServerInstanceObject.DatabaseServer `
            -DatabaseInstance $ServerInstanceObject.DatabaseInstance `
            -DatabaseName $ServerInstanceObject.DatabaseName `
            -SQLCommand $SQLCommand `
            -ErrorAction SilentlyContinue
    }
    catch{
        Write-Warning "Error when creating user $($ServerInstanceObject.ServiceAccount): $($Error[0])"
    }
    try{
       Invoke-SQL `
            -DatabaseServer $ServerInstanceObject.DatabaseServer `
            -DatabaseInstance $ServerInstanceObject.DatabaseInstance `
            -DatabaseName $ServerInstanceObject.DatabaseName `
            -SQLCommand "ALTER ROLE [db_owner] ADD MEMBER [$($ServerInstanceObject.ServiceAccount)]" `
            -ErrorAction SilentlyContinue
    }
    catch{
        Write-Warning "Error when altering user $($ServerInstanceObject.ServiceAccount): $($Error[0])"
    }
         
    $null = Set-NAVServerInstance -Start -ServerInstance $ServerInstance
    if($CreateWebServerInstance){
        Write-Host -ForegroundColor Green -Object "Create WebServerInstance '$ServerInstance'"
        New-NAVWebServerInstance `            -ClientServicesPort $ClientServicesPort `            -Server localhost `            -ServerInstance $ServerInstance `            -WebServerInstance $ServerInstance `            -Force
    }
    if($LicenseFile){  
        Write-Host -ForegroundColor Green -Object 'Importing license..'
        $null = $ServerInstanceObject | Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -Force -WarningAction SilentlyContinue
    }
            
    if ($EnablePortSharing) {
        Enable-NAVServerInstancePortSharing -ServerInstance $ServerInstance
    }
    
    if ($StartWindowsClient) {
        Start-NAVWindowsClient `
            -Port $ServerInstanceObject.ClientServicesPort `
            -ServerInstance $ServerInstanceObject.ServerInstance `
            -ServerName ([net.dns]::gethostname())
    }

    $Object 
}

