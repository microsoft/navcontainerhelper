function Import-NAVServerLicenseToDatabase {
    [cmdletbinding()]
    param(
        [String] $LicenseFile,
        [String] $ServerInstance,
        [ValidateSet('Server','Database')]
        [String] $Scope
    )

    Write-Verbose "Import-NAVServerLicenseToDatabase to $ServerInstance"    
 
    $ServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $ServerInstance

    $DatabaseServer = $ServerInstanceObject.DatabaseServer
    if (!([string]::IsNullOrEmpty($ServerInstanceObject.DatabaseInstance))){
        $DatabaseServer = "$($DatabaseServer)\$($ServerInstanceObject.DatabaseInstance)"
    }
    
    #GetLicenseData
    [Byte[]] $LicenseData = [io.file]::ReadAllBytes($LicenseFile);

    #SQL
    switch($Scope){
        'Server'{
            $connectionString = "Data Source=$DatabaseServer; Integrated Security=SSPI; Initial Catalog=Master"
            $SQLCommand = 'UPDATE [dbo].[$ndo$srvproperty] SET [license] = @License' 
            }
        'Database'{
            $connectionString = "Data Source=$DatabaseServer; Integrated Security=SSPI; Initial Catalog=$($ServerInstanceObject.DatabaseName)"
            $SQLCommand = 'UPDATE [dbo].[$ndo$dbproperty] SET [license] = @License' 
            }
    }
          
    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $null = $command.Parameters.Add('@License', [System.Data.SqlDbType]::Image); 
    $null = $command.Parameters['@License'].Value = $LicenseData; 

    $connection.Open()
    $command.CommandTimeout = $CommandTimeout
    
    $null = $command.ExecuteNonQuery()

    $connection.Close()
    $connection.Dispose()     

}