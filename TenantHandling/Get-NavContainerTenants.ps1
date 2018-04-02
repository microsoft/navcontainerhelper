<# 
 .Synopsis
  Retrieve all Tenants in a multitenant Nav container
 .Description
  Get information about all tenants in the Nav container
 .Parameter containerName
  Name of the container from which you want to get the tenant information
 .Example
  Get-NavContainerTenants -containerName test
#>
function Get-NavContainerTenants {
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock {

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The NAV Container is not setup for multitenancy"
        }

        Get-NavTenant -ServerInstance NAV
    }
}
Export-ModuleMember -Function Get-NavContainerTenants
