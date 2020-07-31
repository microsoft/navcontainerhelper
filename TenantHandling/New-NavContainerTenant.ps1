<# 
 .Synopsis
  Creates a new Tenant in a multitenant NAV/BC Container
 .Description
  Creates a tenant database in the Container and mounts it as a new tenant
 .Parameter containerName
  Name of the container in which you want create a tenant
 .Parameter tenantId
  Name of tenant you want to create in the container
 .Parameter sqlCredential
  Credentials for the SQL server of the tenant database (if using an external SQL Server)
 .Parameter sourceDatabase
  Specify a source database which will be the template for the new tenant (default is tenant)
 .Parameter destinationDatabase
  Specify a database name for the new tenant (default is the tenantid)
 .Example
  New-BcContainerTenant -containerName test2 -tenantId mytenant
#>
function New-BcContainerTenant {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $tenantId,
        [PSCredential] $sqlCredential = $null,
        [string] $sourceDatabase = "tenant",
        [string] $destinationDatabase = $tenantId
    )

    Write-Host "Creating Tenant $tenantId on $containerName"

    if ($tenantId -eq "tenant") {
        throw "You cannot add a tenant called tenant"
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($tenantId, [PSCredential]$sqlCredential, $sourceDatabase, $destinationDatabase)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The Container is not setup for multitenancy"
        }
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value

        # Setup tenant
        Copy-NavDatabase -SourceDatabaseName $sourceDatabase -DestinationDatabaseName $destinationDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseCredentials $sqlCredential
        Mount-NavDatabase -ServerInstance $ServerInstance -TenantId $TenantId -DatabaseName $destinationDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseCredentials $sqlCredential

    } -ArgumentList $tenantId, $sqlCredential, $sourceDatabase, $destinationDatabase
    Write-Host -ForegroundColor Green "Tenant successfully created"
}
Set-Alias -Name New-NavContainerTenant -Value New-BcContainerTenant
Export-ModuleMember -Function New-BcContainerTenant -Alias New-NavContainerTenant
