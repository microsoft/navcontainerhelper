<# 
 .Synopsis
  Removes a Tenant in a multitenant Nav container
 .Description
  Unmounts and removes a tenant database in the Nav container
 .Parameter containerName
  Name of the container in which you want remove a tenant
 .Parameter tenantId
  Name of tenant you want to remove in the container
 .Parameter sqlCredential
  Credentials for the SQL server of the tenant database (if using an external SQL Server)
 .Example
  Remove-NavContainerTenant -containerName test2 -tenantId mytenant
#>
function Remove-NavContainerTenant {
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$tenantId,
        [System.Management.Automation.PSCredential]$sqlCredential = $null
    )

    Write-Host "Removing Tenant $tenantId from $containerName"

    if ($tenantId -eq "tenant") {
        throw "You cannot remove a tenant called tenant"
    }

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($tenantId, [System.Management.Automation.PSCredential]$sqlCredential)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The NAV Container is not setup for multitenancy"
        }
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value

        # Remove tenant
        Write-Host "Dismounting tenant $tenantId"
        Dismount-NavTenant -ServerInstance NAV -Tenant $TenantId -force | Out-null
        Remove-NavDatabase -DatabaseName $TenantId -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseCredentials $sqlCredential

    } -ArgumentList $tenantId, $sqlCredential
    Write-Host -ForegroundColor Green "Tenant successfully removed"
}
Export-ModuleMember -Function Remove-NavContainerTenant
