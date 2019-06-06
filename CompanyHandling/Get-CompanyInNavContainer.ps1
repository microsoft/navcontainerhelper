<# 
 .Synopsis
  Get a list of companies in the NAV/BC Container
 .Description
  Create a session to a container and run Get-NavCompany
 .Parameter containerName
  Name of the container in which you want to get the companies
  .Parameter tenant
  Name of tenant you want to get the commpanies for in the container
 .Example
  Get-CompanyInNavContainer -containerName navserver
#>
function Get-CompanyInNavContainer {
    Param(
        [string] $containerName = "navserver",
        [string] $tenant = "default"
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($tenant)
        Get-NavCompany -ServerInstance $ServerInstance -Tenant $tenant
    } -ArgumentList $tenant | Where-Object {$_ -isnot [System.String]}
}
Set-Alias -Name Get-CompanyInBCContainer -Value Get-CompanyInNavContainer
Export-ModuleMember -Function Get-CompanyInNavContainer -Alias Get-CompanyInBCContainer
