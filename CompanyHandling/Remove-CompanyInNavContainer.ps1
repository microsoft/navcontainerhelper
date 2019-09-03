<# 
 .Synopsis
  Remove a company from the NAV/BC Container
 .Description
  Create a session to a container and run Remove-NavCompany
 .Parameter containerName
  Name of the container from which you want to remove the company
  .Parameter tenant
  Name of tenant you want to remove the commpany from in the container
 .Parameter companyName
  Name of the company you want to remove
 .Example
  Remove-CompanyInNavContainer -containerName test2 -companyName 'My Company' -tenant mytenant
#>
function Remove-CompanyInNavContainer {
    Param (
        [string] $containerName = "navserver",
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $companyName
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($companyName, $tenant)
        Write-Host "Removing company $companyName from $tenant"
        Remove-NavCompany -ServerInstance $ServerInstance -Tenant $tenant -CompanyName $companyName -ForceImmediateDataDeletion -Force
    } -ArgumentList $companyName, $tenant
    Write-Host -ForegroundColor Green "Company successfully removed"
}
Set-Alias -Name Remove-CompanyInBCContainer -Value Remove-CompanyInNavContainer
Export-ModuleMember -Function Remove-CompanyInNavContainer -Alias Remove-CompanyInBCContainer
