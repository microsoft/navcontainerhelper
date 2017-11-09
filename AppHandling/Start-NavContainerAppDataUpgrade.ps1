<# 
 .Synopsis
  Upgrade Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Start-NAVAppDataUpgrade in the container
 .Parameter containerName
  Name of the container in which you want to upgrade the app (default navserver)
 .Parameter appName
  Name of app you want to upgrade in the container
 .Example
  Start-NavContainerAppDataUpgrade -containerName test2 -appName myapp
#>
function  Start-NavContainerAppDataUpgrade {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Upgrading app $appName"
        Start-NAVAppDataUpgrade -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully upgraded"
}
Export-ModuleMember -Function Start-NavContainerAppDataUpgrade
