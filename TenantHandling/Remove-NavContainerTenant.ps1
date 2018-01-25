<# 
 .Synopsis
  Removes a Tenant in a multitenant Nav container
 .Description
  Unmounts and removes a tenant database in the Nav container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter tenantId
  Name of tenant you want to remove in the container
 .Example
  Remove-NavContainerTenant -containerName test2 -tenantId mytenant
#>
function Remove-NavContainerTenant {
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$tenantId
    )

    if ($tenantId -eq "tenant") {
        throw "You cannot remove a tenant called tenant"
    }

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($tenantId)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The NAV Container is not setup for multitenancy"
        }

        Write-Host "Removing Tenant $tenantId"

        # Remove tenant
        Dismount-NavTenant -ServerInstance NAV -Tenant $TenantId -force | Out-null

    } -ArgumentList $tenantId
    Write-Host -ForegroundColor Green "Tenant successfully removed"
}
Export-ModuleMember -Function Remove-NavContainerTenant
