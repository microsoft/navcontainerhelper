<# 
 .Synopsis
  Uninstall Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Uninstall-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to uninstall the app (default navserver)
 .Parameter appName
  Name of app you want to uninstall in the container
 .Example
  Uninstall-NavApp -containerName test2 -appName myapp
#>
function UnInstall-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Uninstalling app $appName"
        Uninstall-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully uninstalled"
}
Export-ModuleMember -Function UnInstall-NavContainerApp
