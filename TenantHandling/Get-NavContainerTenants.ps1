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
    [CmdletBinding(DefaultParameterSetName = 'UseContainerName')]
    Param (
        [Parameter(Mandatory = $false)]
        [string] $containerName = "navserver",

        [Parameter(Mandatory = $true, ParameterSetName = 'ForceRefreshTenantState')]
        [switch] $ForceRefresh,

        [Parameter(Mandatory = $false, ParameterSetName = 'ForceRefreshTenantState')]
        [ValidateNotNullorEmpty()]
        [string] $Tenant = 'default',

        [switch] $Force
    )
    $Params = @{ "Force" = $Force }
    If ($ForceRefresh) {
        $Params += @{
            "ForceRefresh" = $ForceRefresh
            "Tenant" = $Tenant
        }
    }
    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock {
        Param( [PsCustomObject] $Params)
        Get-NavTenant -ServerInstance $ServerInstance @Params
    } -argumentList $Params
}
Set-Alias -Name Get-BCContainerTenants -Value Get-NavContainerTenants
Export-ModuleMember -Function Get-NavContainerTenants -Alias Get-BCContainerTenants
