<# 
 .Synopsis
  Sync Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Sync-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter appName
  Name of app you want to install in the container
 .Example
  Install-NavApp -containerName test2 -appName myapp
#>
function Sync-NavContainerApp {
    Param(
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )
    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName,$tenant)
        Write-Host "Synchronizing $appFile on $tenant"
        Sync-NavTenant -ServerInstance NAV -Tenant $tenant -Force
        Sync-NavApp -ServerInstance NAV -Name $appName -Tenant $tenant
    } -ArgumentList $appName, $tenant
    Write-Host -ForegroundColor Green "App successfully synchronized"
}
Export-ModuleMember -Function Sync-NavContainerApp
