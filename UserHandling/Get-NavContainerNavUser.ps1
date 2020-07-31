<# 
 .Synopsis
  Get list of users from NAV/BC Container
 .Description
  Retrieve the list of user objects from a tenant in a NAV/BC Container
 .Parameter containerName
  Name of the container from which you want to get the users (default navserver)
 .Parameter tenant
  Name of tenant from which you want to get the users
 .Example
  Get-BcContainerNavUser
 .Example
  Get-BcContainerNavUser -containerName test -tenant mytenant
#>
function Get-BcContainerBcUser {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default"
    )

    PROCESS
    {
        Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { param($tenant)
            Get-NavServerUser -ServerInstance $ServerInstance -tenant $tenant
        } -ArgumentList $tenant | Where-Object {$_ -isnot [System.String]}
    }
}
Set-Alias -Name Get-NavContainerNavUser -Value Get-BcContainerBcUser
Export-ModuleMember -Function Get-BcContainerBcUser -Alias Get-NavContainerNavUser
