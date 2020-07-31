<# 
 .Synopsis
  Retrieve Tenants in a multitenant NAV/BC Container
 .Description
  Get information about tenants in the Container
 .Parameter containerName
  Name of the container from which you want to get the tenant information
 .Parameter Tenant
  Specifies the ID of the specific tenant that you want to get information about, such as Tenant1. Shows all if not specified.
 .Parameter forceRefresh
  Specifies to update a tenant's state and data version based, in part, on the data version of the tenant database that contains the tenant. 
 .Parameter force
  Forces the command to run without asking for user confirmation.
 .Example
  Get-BcContainerTenants -containerName test
#>
function Get-BcContainerTenants {
    [CmdletBinding(DefaultParameterSetName = 'UseContainerName')]
    Param (
        [ValidateNotNullorEmpty()]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ForceRefreshTenantState')]
        [switch] $ForceRefresh,

        [string] $Tenant = "",

        [switch] $Force
    )
    $Params = @{ "Force" = $Force }
    If ($ForceRefresh) {
        $Params += @{ "ForceRefresh" = $ForceRefresh }
        if (-not $tenant) {
            $tenant = "Default"
        }
    }
    if ($Tenant) {
        $Params += @{ "Tenant" = $Tenant }
    }
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock {
        Param( [PsCustomObject] $Params)
        Get-NavTenant -ServerInstance $ServerInstance @Params
    } -argumentList $Params
}
Set-Alias -Name Get-NavContainerTenants -Value Get-BcContainerTenants
Export-ModuleMember -Function Get-BcContainerTenants -Alias Get-NavContainerTenants
