<# 
 .Synopsis
  Copy company in the database
 .Description
  Create a session to a Nav container and run New-NavCompany
 .Parameter containerName
  Name of the container in which you want to create the company
  .Parameter tenant
  Name of tenant you want to create the commpany for in the container
 .Parameter fromCompanyName
  Name of the source company
 .Parameter toCompanyName
  Name of the destination company
 .Example
  Copy-CompanyInNavContainer -containerName test2 -fromCompanyName 'Cronus International Ltd.' -toCompanyName 'Cronus Subsidiary' -tenant mytenant
#>
function Copy-CompanyInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [string]$fromCompanyName,
        [switch]$toCompanyName
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($fromCompanyName, $toCompanyName, $tenant)
        Write-Host "Copying company from $fromCompanyName to $toCompanyName in $tenant"
        Copy-NAVCompany -ServerInstance NAV -Tenant $tenant -SourceCompanyName $fromCompanyName -DestinationCompanyName $toCompanyName
    } -ArgumentList $fromCompanyName, $toCompanyName, $tenant
    Write-Host -ForegroundColor Green "Company successfully copied"
}
Export-ModuleMember -Function Copy-CompanyInNavContainer