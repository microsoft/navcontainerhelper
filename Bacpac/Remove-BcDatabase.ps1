<# 
 .Synopsis
  Remove Business Central Database(s) from SQL Server
 .Description
  Remove Business Central Database(s) from SQL Server
  Windows Authentication to the SQL Server is required.
 .Parameter databaseServer
  database Server from which you want to remove the database(s)
 .Parameter databaseInstance
  database Instance on the database Server from which you want to remove the database(s)
 .Parameter databaseName
  database name of the database(s) you want to remove
#>
function Remove-BcDatabase {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $databaseServer,
        [Parameter(Mandatory=$false)]
        [string] $databaseInstance = "",
        [Parameter(Mandatory=$true)]
        [string] $databaseName
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if ($databaseServer -eq 'host.containerhelper.internal') {
        $databaseServer = 'localhost'
    }
    $databaseServerInstance = $databaseServer
    if ($databaseInstance) {
        $databaseServerInstance += "\$databaseInstance"
    }
    if ($databaseName.Contains('%')) {
        $op = "like"
    }
    else {
        $op = "="
    }

    $dbFiles = Invoke-SqlCmd `
                    -ServerInstance $databaseserverinstance `
                    -Query "SELECT f.physical_name FROM sys.sysdatabases db INNER JOIN sys.master_files f ON f.database_id = db.dbid WHERE db.name $op '$DatabaseName'" | ForEach-Object { $_.physical_name }

    $databases = Invoke-SqlCmd `
        -ServerInstance $databaseserverinstance `
        -Query "SELECT * FROM sys.sysdatabases WHERE name  $op '$DatabaseName'" | ForEach-Object { $_.name }

    $databases | ForEach-Object {

        Write-Host "Setting database $_ offline"
        Invoke-SqlCmd `
            -ServerInstance $DatabaseServerInstance `
            -Query "ALTER DATABASE [$_] SET OFFLINE WITH ROLLBACK IMMEDIATE"

        Write-Host "Removing database $_"
        Invoke-SqlCmd `
            -ServerInstance $DatabaseServerInstance `
            -Query "DROP DATABASE [$_]"
    }

    $path = ''
    $dbFiles | ForEach-Object {
        if ($databaseServer -ne "localhost") {
            $qualifier = $_ | Split-Path -Qualifier
            $newQualifier = '\\{0}\{1}' -f $databaseServer, $qualifier.Replace(':','$').ToLower()
            $path = $_.Replace($qualifier, $newQualifier)
        } else {
            $path = $_
        }
        if (Test-Path $path) { Remove-Item -Path $path -Force }
    }

    if ([string]::IsNullOrEmpty($path) -eq $false -and
       (Test-Path ($path | Split-Path -Parent)) -eq $true -and
       [string]::IsNullOrEmpty((Get-ChildItem -Path ($path | Split-Path -Parent))) -eq $true) {

        Remove-Item -Path ($path | Split-Path -Parent) -Force -ErrorAction Continue
    } 
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Remove-BcDatabase
