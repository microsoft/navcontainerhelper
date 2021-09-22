function Get-SQLBackupDatabaseName
{
    [cmdletbinding()]
    param(
        [String] $Backupfile
    )

    import-module 'sqlps' -DisableNameChecking

    $null = get-item $Backupfile -ErrorAction Stop

    $srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') ([net.dns]::GetHostName())
    $rs = new-object('Microsoft.SqlServer.Management.Smo.Restore')
    $bdi = new-object ('Microsoft.SqlServer.Management.Smo.BackupDeviceItem') ($Backupfile, 'File')
    $rs.Devices.Add($bdi)

    return $rs.ReadBackupHeader($srv).Databasename
}

