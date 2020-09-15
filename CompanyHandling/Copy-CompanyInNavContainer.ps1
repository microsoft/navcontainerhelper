<# 
 .Synopsis
  Copy company in a NAV/BC Container
 .Description
  Create a session to a container and run Copy-NavCompany
 .Parameter containerName
  Name of the container in which you want to create the company
  .Parameter tenant
  Name of tenant you want to create the commpany for in the container
 .Parameter sourceCompanyName
  Name of the source company
 .Parameter destinationCompanyName
  Name of the destination company
 .Example
  Copy-CompanyInBcContainer -containerName test2 -sourceCompanyName 'Cronus International Ltd.' -destinationCompanyName 'Cronus Subsidiary' -tenant mytenant
#>
function Copy-CompanyInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $sourceCompanyName,
        [Parameter(Mandatory=$true)]
        [string] $destinationCompanyName
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($sourceCompanyName, $destinationCompanyName, $tenant)
        Write-Host "Copying company from $sourceCompanyName to $destinationCompanyName in $tenant"
        Copy-NAVCompany -ServerInstance $ServerInstance -Tenant $tenant -SourceCompanyName $sourceCompanyName -DestinationCompanyName $destinationCompanyName
    } -ArgumentList $sourceCompanyName, $destinationCompanyName, $tenant
    Write-Host -ForegroundColor Green "Company successfully copied"
}
Set-Alias -Name Copy-CompanyInNavContainer -Value Copy-CompanyInBcContainer
Export-ModuleMember -Function Copy-CompanyInBcContainer -Alias Copy-CompanyInNavContainer
