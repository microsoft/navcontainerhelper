<# 
 .Synopsis
  Get App Info from NAV/BC Container
 .Description
  Creates a session to the NAV/BC Container and runs the CmdLet Get-NavAppInfo in the container
 .Parameter containerName
  Name of the container in which you want to enumerate apps (default navserver)
 .Parameter tenant
  Specifies the tenant from which you want to get the app info
 .Parameter tenantSpecificProperties
  Specifies whether you want to get the tenant specific app properties
 .Parameter symbolsOnly
  Specifies whether you only want apps, which are of packagetype SymbolsOnly (Specifying SymbolsOnly ignores the tenant parameter)
 .Example
  Get-NavContainerAppInfo -containerName test2
 .Example
  Get-NavContainerAppInfo -containerName test2 -tenant mytenant -tenantSpecificProperties
 .Example
  Get-NavContainerAppInfo -containerName test2 -symbolsOnly
#>
function Get-NavContainerAppInfo {
    Param(
        [string] $containerName = "navserver",
        [string] $tenant = "",
        [switch] $symbolsOnly,
        [switch] $tenantSpecificProperties
    )

    $args = @{}
    if ($symbolsOnly) {
        $args += @{ "SymbolsOnly" = $true }
    } else {
        if ($tenantSpecificProperties) {
            $args += @{ "TenantSpecificProperties" = $true }
        }
        if ("$tenant" -eq "") {
            $tenant = "default"
        }
        $args += @{ "Tenant" = $tenant }
    }

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($inArgs)
        Get-NavAppInfo -ServerInstance $ServerInstance @inArgs
    } -ArgumentList $args
}
Set-Alias -Name Get-BCContainerAppInfo -Value Get-NavContainerAppInfo
Export-ModuleMember -Function Get-NavContainerAppInfo -Alias Get-BCContainerAppInfo
