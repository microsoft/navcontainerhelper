<# 
 .Synopsis
  Invoke Api in Nav Container
 .Description
  Invoke an Api in a NAV Container.
 .Parameter containerName
  Name of the container in which you want to invoke an api
 .Parameter tenant
  Name of the tenant in which context you want to invoke an api
 .Parameter Credential
  Credentials for the user making invoking the api (do not specify if using Windows auth)
 .Parameter CompanyName
  CompanyName for which you want to get the Company Id (leave empty to get company Id for the default company)
 .Example
  $companyId = Get-NavContainerNavUserCompanyId -containerName $containerName -credential $credential
 .Example
  $companyId = Get-NavContainerNavUserCompanyId -containerName $containerName -credential $credential -CompanyName 'CRONUS International Ltd.'
#>
function Get-NavContainerApiCompanyId {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$credential = $null,
        [Parameter(Mandatory=$false)]
        [string]$CompanyName = ""
    )

    if (!($CompanyName)) {

        $customConfig = Get-NavContainerServerConfiguration -ContainerName $containerName
    
        if ($credential) {
            $username = $credential.UserName
        } else {
            $username = whoami
        }
        
        $user = Get-NavContainerNavUser -containerName $containerName -tenant $tenant | Where-Object { $_.Username -eq $Username }
        if (!($CompanyName)) {
            if ($user) {
                $CompanyName = $user.Company
            }
        }
        if (!($CompanyName)) {
            $CompanyName = $customConfig.ServicesDefaultCompany
        }
        if (!($CompanyName)) {
            $Company = Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param($tenant)
                Get-NavCompany -ServerInstance NAV -tenant default
            } -argumentList $tenant | Where-Object { $_ -isnot [System.String] }
            $CompanyName = $Company | Select-Object -First 1 -ExpandProperty CompanyName
        }
    }

    $companyFilter = [Uri]::EscapeDataString("name eq '$CompanyName'")
    
    $result = Invoke-NavContainerApi -containerName $containerName -tenant $tenant -APIVersion "beta" -Query "companies?`$filter=$companyFilter" -credential $credential
    $result.value | Select-Object -First 1 -ExpandProperty id
}
Export-ModuleMember -Function Get-NavContainerApiCompanyId
