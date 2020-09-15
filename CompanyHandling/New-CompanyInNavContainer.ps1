<# 
 .Synopsis
  Create a new company in the NAV/BC Container
 .Description
  Create a session to a container and run New-NavCompany
 .Parameter containerName
  Name of the container in which you want to create the company
  .Parameter tenant
  Name of tenant you want to create the commpany for in the container
 .Parameter companyName
  Name of the new company
 .Parameter evaluationCompany
  Specifies whether the company that you want to create is an evaluation company
 .Example
  New-CompanyInBcContainer -containerName test2 -companyName 'My Company' -tenant mytenant
#>
function New-CompanyInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $companyName,
        [switch] $evaluationCompany
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($companyName, $evaluationCompany, $tenant)
        Write-Host "Creating company $companyName in $tenant"
        New-NavCompany -ServerInstance $ServerInstance -Tenant $tenant -CompanyName $companyName -EvaluationCompany:$evaluationCompany
    } -ArgumentList $companyName, $evaluationCompany, $tenant
    Write-Host -ForegroundColor Green "Company successfully created"
}
Set-Alias -Name New-CompanyInNavContainer -Value New-CompanyInBcContainer
Export-ModuleMember -Function New-CompanyInBcContainer -Alias New-CompanyInNavContainer
