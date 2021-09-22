function Invoke-NAVSQL {
<#
.Synopsis
    Executes a SQL Statement on the database server of an NAV ServerInstance
.DESCRIPTION
    Will return an object model when records were retrieved
.NOTES
   
.PREREQUISITES
    Use Microsoft.Dynamics.NAV.Management module
    Uses Get-NAVServerInstanceDetails
.EXAMPLE
    Example 1:
        Invoke-NAVSQL -ServerInstance DEV -SQLCommand "select * from [$('$ndo$dbproperty')]" -Verbose
            Gets all columns of the table $ndo$dbproperty that resides in the database of Server Instance "DEV"

    Example 2:
        $Companies = Invoke-NAVSQL -ServerInstance DEV -SQLCommand 'select * from Company'
     
#>
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $ServerInstance,
        [Parameter(Mandatory=$true)]
        [string] $SQLCommand = '',
        [parameter(Mandatory=$false)]
        [switch] $ShowWriteHost,
        [parameter(Mandatory=$false)]
        [int] $CommandTimeout=30
      )

    Write-Verbose "Invoke-NAVSQL $ServerInstance $SQLCommand"
     
    $ServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $ServerInstance

    $DatabaseServer = $ServerInstanceObject.DatabaseServer
    if (!([string]::IsNullOrEmpty($ServerInstanceObject.DatabaseInstance))){
        $DatabaseServer = "$($DatabaseServer)\$($ServerInstanceObject.DatabaseInstance)"
    }
    $connectionString = "Data Source=$DatabaseServer; Integrated Security=SSPI; Initial Catalog=$($ServerInstanceObject.DatabaseName)"

    if ($ShowWriteHost){
        write-Host -ForegroundColor Green "Invoke-SQL with this statement on database '$($ServerInstanceObject.DatabaseName)':"
        Write-Host -ForegroundColor Gray $SQLCommand
    }

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()
    $command.CommandTimeout = $CommandTimeout
    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    $connection.Dispose()
    
    if ($dataset.Tables.Count -gt 1){
        return $dataset.Tables
    } else {
        $Result = @()
        foreach($table in $dataSet.Tables){
            foreach($Row in $table.Rows){
        
                $ResultObject = New-Object PSObject

                foreach($column in $table.Columns){
                    $ResultObject | Add-Member -MemberType NoteProperty -Name $column.columnName -Value $row.$column
                }
                $Result += $ResultObject
            }
        }
        return $Result
    }
}