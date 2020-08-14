<# 
 .Synopsis
  Removes a Tenant in a multitenant NAV/BC Container
 .Description
  Unmounts and removes a tenant database in the Container
 .Parameter containerName
  Name of the container in which you want remove a tenant
 .Parameter tenantId
  Name of tenant you want to remove in the container
 .Parameter sqlCredential
  Credentials for the SQL server of the tenant database (if using an external SQL Server)
 .Parameter databaseName
  Specify a database name of the tenant you want to remove (default is the tenantId)
 .Example
  Remove-BcContainerTenant -containerName test2 -tenantId mytenant
#>
function Remove-BcContainerTenant {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $tenantId,
        [string] $databaseName = $tenantId,
        [PSCredential] $sqlCredential = $null
    )

    Write-Host "Removing Tenant $tenantId from $containerName"

    if ($tenantId -eq "tenant") {
        throw "You cannot remove a tenant called tenant"
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($tenantId, [PSCredential]$sqlCredential, $databaseName)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The Container is not setup for multitenancy"
        }
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value

        # Remove tenant
        Write-Host "Dismounting tenant $tenantId"
        Dismount-NavTenant -ServerInstance $ServerInstance -Tenant $TenantId -force | Out-null
        Remove-NavDatabase -DatabaseName $databaseName -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseCredentials $sqlCredential

    } -ArgumentList $tenantId, $sqlCredential, $databaseName
    Write-Host -ForegroundColor Green "Tenant successfully removed"
}
Set-Alias -Name Remove-NavContainerTenant -Value Remove-BcContainerTenant
Export-ModuleMember -Function Remove-BcContainerTenant -Alias Remove-NavContainerTenant
