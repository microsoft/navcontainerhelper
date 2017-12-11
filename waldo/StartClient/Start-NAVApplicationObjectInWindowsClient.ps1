function Start-NAVApplicationObjectInWindowsClient
{
    [cmdletbinding()]
    param(
        [string]$ServerName=[net.dns]::Gethostname(), 
        [int]$Port=7046, 
        [String]$ServerInstance, 
        [String]$Companyname, 
        [string]$Tenant='default',
        [ValidateSet('Table','Page','Report','Codeunit','Query','XMLPort')]
        [String]$ObjectType,
        [int]$ObjectID
         )

    $ConnectionString = "DynamicsNAV://$Servername" + ":$Port/$ServerInstance/$Companyname/Run$ObjectType"+"?$ObjectType=$ObjectID&tenant=$tenant"
    Write-Verbose "Connectionstring: $ConnectionString ..."
    Start-Process $ConnectionString
}
