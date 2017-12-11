function ConvertTo-NAVMultiTenantEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [System.String]
        $ServerInstance,
        
        [Parameter(Mandatory=$false, Position=1)]
        [System.String]
        $MainTenantId,
        
        [Parameter(Mandatory=$false, Position=2)]
        [Object]
        $DatabaseServer = [net.dns]::GetHostName(),
        
        [Parameter(Mandatory=$false, Position=3)]
        [System.String]
        $DatabaseInstance = ''
    )
    Write-Host -ForegroundColor Green "Converting $ServerInstance to MultiTenancy with Tenant $MainTenantId ..."
    
    if ([string]::IsNullOrEmpty($MainTenantId)){
        $MainTenantId = 'default'
    }
    
    $ServerInstanceDB = (Get-NAVServerConfiguration2 -ServerInstance $ServerInstance | Where Key -eq DatabaseName).Value
    
    $ServerInstanceAppDB = $ServerInstanceDB + '_Application'
    
    export-navapplication -DatabaseServer $DatabaseServer -DatabaseName $ServerInstanceDB -DatabaseInstance $DatabaseInstance -DestinationDatabaseName $ServerInstanceAppDB
    remove-navapplication -DatabaseServer $DatabaseServer -DatabaseName $ServerInstanceDB -DatabaseInstance $DatabaseInstance -Force
    
    Set-NAVServerConfiguration -ServerInstance $Serverinstance -KeyName DatabaseName -KeyValue '' -WarningAction SilentlyContinue
    Set-NAVServerConfiguration -ServerInstance $Serverinstance -KeyName Multitenant -KeyValue $true -WarningAction SilentlyContinue
    Set-NAVServerInstance -ServerInstance $ServerInstance -Restart
    
    Mount-NAVApplication -DatabaseServer $DatabaseServer -DatabaseName $ServerInstanceAppDB -DatabaseInstance $DatabaseInstance -ServerInstance $ServerInstance -Force
    Mount-NAVTenant -DatabaseServer $DatabaseServer -DatabaseName $ServerInstanceDB -DatabaseInstance $DatabaseInstance -ServerInstance $ServerInstance -AllowAppDatabaseWrite -Id $MainTenantID -Force -OverwriteTenantIdInDatabase
    
    Sync-navtenant -ServerInstance $ServerInstance -Tenant $MainTenantID -Mode ForceSync -Force
}

