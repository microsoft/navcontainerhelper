function New-NAVUpgradeApplicationDB
{
    [CmdLetBinding()]
    param(
        [String] $TargetServerInstance,
        [String] $LicenseFile,
        [String] $TextFileFolder,
        [String] $WorkingFolder,
        [String] $Name
    )

    write-Host -foregroundColor Green -Object 'Creating Multi Tenant Application DB'

    if (!($name)){
        $Name = $TargetServerInstance
    }

    $TargetServerInstanceObject = Get-NAVServerInstance -ServerInstance $TargetServerInstance -ErrorAction Stop
    $WorkingServerInstance = "$($Name)_Result"

    #Creating Workspace
    $LogFolder = Join-Path $WorkingFolder 'Log_NAVUpgradeApplicationDB'
    if(Test-Path $LogFolder){Remove-Item $LogFolder -Force -Recurse}
    $LogImportText       = join-path $LogFolder '01_ImportText'
    $LogCompileObjects   = join-path $LogFolder '02_CompileObjects'
    $LogResultObjectFile = join-path $LogFolder '03_ExportFob'

    $ResultObjectFile    = Join-Path $WorkingFolder 'Result.fob'

    #Create WorkingDB
    Copy-NAVEnvironment `
        -ServerInstance $TargetServerInstance `
        -ToServerInstance $WorkingServerInstance
    
    #Import NAV LIcense
    if (!([string]::IsNullOrEmpty($LicenseFile))){
        Write-Host "Import NAV license in $WorkingServerInstance" -ForegroundColor Green
        Get-NAVServerInstance -ServerInstance $WorkingServerInstance | Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -WarningAction SilentlyContinue -ErrorAction Continue
        Set-NAVServerInstance -Restart -ServerInstance $WorkingServerInstance -ErrorAction Stop
    }
    
    #Import Objects
    Write-Host 'Import Merged Objects' -ForegroundColor Green
    $null = Import-NAVApplicationObject `
    -DatabaseName $WorkingServerInstance `
    -Path "$TextFileFolder\*.txt" `
    -LogPath $LogImportText `
    -NavServerName ([net.dns]::GetHostName()) `
    -NavServerInstance $WorkingServerInstance `
    -confirm:$false
       
    #Compile Objects
    Write-Host 'Compile Uncompiled' -ForegroundColor Green
    $null = 
        Compile-NAVApplicationObject `
            -DatabaseName $WorkingServerInstance `
            -LogPath $LogCompileObjects `
            -SynchronizeSchemaChanges Force `
            -Filter 'Compiled=0' `
            -Recompile `
            -NavServerName ([net.dns]::GetHostName()) `
            -NavServerInstance $WorkingServerInstance 
    

    $null = 
        ConvertTo-NAVMultiTenantEnvironment `
            -ServerInstance $WorkingServerInstance `
            -MainTenantId 'Default'

    $null = 
        Dismount-NAVTenant `
            -ServerInstance $WorkingServerInstance `
            -Tenant 'Default' `
            -Force

    $null =
        Drop-SQLDatabaseIfExists `            -Databasename $WorkingServerInstance

    $ResultServerInstance = Get-NAVServerInstance $WorkingServerInstance
    return $ResultServerInstance
}

