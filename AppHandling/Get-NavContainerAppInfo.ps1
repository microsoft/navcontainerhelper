<# 
 .Synopsis
  Get Nav App Info from Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Get-NavAppInfo in the container
 .Parameter containerName
  Name of the container in which you want to enumerate apps (default navserver)
 .Parameter symbolsOnly
  Specifies whether you only want apps, which are of packagetype SymbolsOnly
 .Example
  Get-NavContainerAppInfo -containerName test2
#>
function Get-NavContainerAppInfo {
    Param(
        [string]$containerName = "navserver",
        [switch]$symbolsOnly,
        
        [Parameter(Mandatory = $false)]
        [switch]
        $tenantSpecificProperties,
        
        [Parameter(Mandatory = $false)]
        [String]
        $tenant
    )

    $args = @{
        ServerInstance = "NAV"
    }
    if ($symbolsOnly) {
        $args += @{ SymbolsOnly = $true }
    }
    if ($tenantSpecificProperties) {
        if ("$tenant" -eq "") {
            $tenant = "default"
        }
         
        $args += @{ Tenant = $tenant }
        $args += @{ TenantSpecificProperties = $true }
    }

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { 
        param(
            $inArgs
        )
        Get-NavAppInfo @inArgs
    } -ArgumentList $args
}
Export-ModuleMember -Function Get-NavContainerAppInfo