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
  Get-CompanyInBcContainer -containerName navserver
#>
function Get-CompanyInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $tenant = "default"
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($tenant)
        Get-NavCompany -ServerInstance $ServerInstance -Tenant $tenant
    } -ArgumentList $tenant | Where-Object {$_ -isnot [System.String]}
}
Set-Alias -Name Get-CompanyInNavContainer -Value Get-CompanyInBcContainer
Export-ModuleMember -Function Get-CompanyInBcContainer -Alias Get-CompanyInNavContainer
