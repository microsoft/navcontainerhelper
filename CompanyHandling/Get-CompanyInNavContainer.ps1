<# 
 .Synopsis
  Get a list of companies in the database
 .Description
  Create a session to a Nav container and run Get-NavCompany
 .Parameter containerName
  Name of the container in which you want to get the companies
  .Parameter tenant
  Name of tenant you want to get the commpanies for in the container
 .Example
  Get-CompanyInNavContainer -containerName navserver
#>
function Get-CompanyInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default"
    )

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($tenant)
        Get-NavCompany -ServerInstance NAV -Tenant $tenant
    } -ArgumentList $tenant
}
Export-ModuleMember -Function Get-CompanyInNavContainer
