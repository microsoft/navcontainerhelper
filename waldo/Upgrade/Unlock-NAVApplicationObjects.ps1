function Unlock-NAVApplicationObjects
{
    param(
    [String] $ServerInstance
    )

    $ServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $ServerInstance

    $DatabaseServer =  $ServerInstanceObject.DatabaseServer
    if (!([string]::IsNullOrEmpty($ServerInstanceObject.DatabaseInstance))){
        $DatabaseServer += "\$($ServerInstanceObject.DatabaseInstance)"
    }

    Invoke-SQL `
        -DatabaseServer $DatabaseServer `
        -DatabaseName $ServerInstanceObject.DatabaseName `
        -SQLCommand "UPDATE [$($ServerInstanceObject.DatabaseName)].[dbo].[Object] SET [Locked]=0,[Locked By]=''"
           
}
    
