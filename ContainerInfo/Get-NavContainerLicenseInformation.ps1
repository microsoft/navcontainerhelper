<# 
 .Synopsis
  Retrieve the Business Central license information from a NAV/BC Container 
 .Description
  Returns the license information used on the Business Central service in the container.
 .Parameter containerName
  Name of the container for which you want to get the license information
 .Example
  Get-BcContainerLicenseInformation -ContainerName "MyContainer"
#>
Function Get-BcContainerLicenseInformation {
    Param (
        [String] $ContainerName = $bcContainerHelperConfig.defaultContainerName
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock {
        $firstAvailableTenant = (Get-NavServerInstance | Get-NavTenant | Where-Object { $_.State -eq 'Operational'})[0].Id
        Get-NavServerInstance | Export-NAVServerLicenseInformation -Tenant $firstAvailableTenant
    }
}
Set-Alias -Name Get-NavContainerLicenseInformation -Value Get-BcContainerLicenseInformation
Export-ModuleMember -Function Get-BcContainerLicenseInformation -Alias Get-NavContainerLicenseInformation