<#
.Synopsis
   Executes a SQL Statement on the database server 
.DESCRIPTION
   Will return an object model when records were retrieved
.NOTES
   
.PREREQUISITES
   
#>

function Invoke-SQL {
    [CmdLetBinding()]
    param(
        [string] $DatabaseServer = [net.dns]::gethostname(),
        [String] $DatabaseInstance = '',
        [string] $DatabaseName = 'Master',
        [string] $SQLCommand = $(throw 'Please specify a query.')
      )

    if (!([string]::IsNullOrEmpty($DatabaseInstance))){
        $DatabaseServer = "$($DatabaseServer)\$($DatabaseInstance)"
    }
    $connectionString = "Data Source=$DatabaseServer; Integrated Security=SSPI; Initial Catalog=$DatabaseName"

    write-Host -ForegroundColor Green "Invoke-SQL with this statement on database '$DatabaseName':"
    Write-Host -ForegroundColor Gray $SQLCommand

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    $connection.Dispose()

    $dataSet.Tables
     
}