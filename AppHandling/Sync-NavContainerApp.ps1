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
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )
    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Synchronizing app $appFile"
        Sync-NavTenant -ServerInstance NAV -Tenant default -Force
        Sync-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully synchronized"
}
Export-ModuleMember -Function Sync-NavContainerApp
