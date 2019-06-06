<# 
 .Synopsis
  Retrieve all Tenants in a multitenant NAV/BC Container
 .Description
  Get information about all tenants in the Container
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

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock {

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The Container is not setup for multitenancy"
        }

        Get-NavTenant -ServerInstance $ServerInstance
    }
}
Set-Alias -Name Get-BCContainerTenants -Value Get-NavContainerTenants
Export-ModuleMember -Function Get-NavContainerTenants -Alias Get-BCContainerTenants
