<# 
 .Synopsis
  Unpublish Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Unpublish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to unpublish the app (default navserver)
 .Parameter appName
  Name of app you want to unpublish in the container
 .Example
  Unpublish-NavApp -containerName test2 -appName myapp
#>
function UnPublish-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Unpublishing app $appName"
        Unpublish-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully unpublished"
}
Export-ModuleMember -Function UnPublish-NavContainerApp
