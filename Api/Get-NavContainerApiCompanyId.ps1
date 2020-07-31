<# 
 .Synopsis
  Invoke Api in Container
 .Description
  Invoke an Api in a Container.
 .Parameter containerName
  Name of the container in which you want to invoke an api
 .Parameter tenant
  Name of the tenant in which context you want to invoke an api
 .Parameter Credential
  Credentials for the user making invoking the api (do not specify if using Windows auth)
 .Parameter CompanyName
  CompanyName for which you want to get the Company Id (leave empty to get company Id for the default company)
 .Example
  $companyId = Get-BcContainerApiCompanyId -containerName $containerName -credential $credential
 .Example
  $companyId = Get-BcContainerApiCompanyId -containerName $containerName -credential $credential -CompanyName 'CRONUS International Ltd.'
#>
function Get-BcContainerApiCompanyId {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [Parameter(Mandatory=$false)]
        [string] $APIVersion = "beta",
        [Parameter(Mandatory=$false)]
        [string] $CompanyName = "",
        [switch] $silent
    )

    if (!($CompanyName)) {

        $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName
    
        if ($credential) {
            $username = $credential.UserName
        } else {
            $username = whoami
        }
        
        $user = Get-BcContainerNavUser -containerName $containerName -tenant $tenant | Where-Object { $_.Username -eq $Username }
        if (!($CompanyName)) {
            if ($user) {
                $CompanyName = $user.Company
            }
        }
        if (!($CompanyName)) {
            $CompanyName = $customConfig.ServicesDefaultCompany
        }
        if (!($CompanyName)) {
            $Company = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($tenant)
                Get-NavCompany -ServerInstance $serverInstance -tenant default
            } -argumentList $tenant | Where-Object { $_ -isnot [System.String] }
            $CompanyName = $Company | Select-Object -First 1 -ExpandProperty CompanyName
        }
    }

    $companyFilter = [Uri]::EscapeDataString("name eq '$CompanyName'")
    
    $result = Invoke-BcContainerApi -containerName $containerName -tenant $tenant -APIVersion $APIVersion -Query "companies?`$filter=$companyFilter" -credential $credential -silent:$silent
    $result.value | Select-Object -First 1 -ExpandProperty id
}
Set-Alias -Name Get-NavContainerApiCompanyId -Value Get-BcContainerApiCompanyId
Export-ModuleMember -Function Get-BcContainerApiCompanyId -Alias Get-NavContainerApiCompanyId
