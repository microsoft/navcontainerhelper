function Drop-SQLDatabaseIfExists {
    param ([String]$SQLServer="(local)", $Databasename)
    
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null
     
    $smoserver = New-Object ( "Microsoft.SqlServer.Management.Smo.Server" ) $SQLServer
    
    if ($smoserver.Databases[$Databasename]) {
        $smoserver.KillAllProcesses($Databasename)
        $smoserver.Databases[$Databasename].drop() 
    }
}


