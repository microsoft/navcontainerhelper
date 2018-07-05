<# 
 .Synopsis
  Create a new company in the database
 .Description
  Create a session to a Nav container and run New-NavCompany
 .Parameter containerName
  Name of the container in which you want to create the company
  .Parameter tenant
  Name of tenant you want to create the commpany for in the container
 .Parameter companyName
  Name of the new company
 .Parameter evaluationCompany
  Specifies whether the company that you want to create is an evaluation company
 .Example
  New-CompanyInNavContainer -containerName test2 -companyName 'My Company' -tenant mytenant
#>
function New-CompanyInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [string]$companyName,
        [switch]$evaluationCompany
    )

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($companyName, $evaluationCompany, $tenant)
        Write-Host "Creating company $companyName in $tenant"
        New-NavCompany -ServerInstance NAV -Tenant $tenant -CompanyName $companyName -EvaluationCompany:$evaluationCompany
    } -ArgumentList $companyName, $evaluationCompany, $tenant
    Write-Host -ForegroundColor Green "Company successfully created"
}
Export-ModuleMember -Function New-CompanyInNavContainer
