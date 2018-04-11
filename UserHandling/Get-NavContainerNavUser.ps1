<# 
 .Synopsis
  Get list of users from container
 .Description
  Retrieve the list of user objects from a tenant in a container
 .Parameter containerName
  Name of the container from which you want to get the users (default navserver)
 .Parameter tenant
  Name of tenant from which you want to get the users
 .Example
  Get-NavContainerNavUser
 .Example
  Get-NavContainerNavUser -containerName test -tenant mytenant
#>
function Get-NavContainerNavUser {
Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default"
    )

    PROCESS
    {
        $session = Get-NavContainerSession -containerName $containerName -silent
        Invoke-Command -Session $session -ScriptBlock { param($tenant)

            Get-NavServerUser -ServerInstance NAV -tenant $tenant
        } -ArgumentList $tenant
    }
}
Export-ModuleMember -Function Get-NavContainerNavUser
