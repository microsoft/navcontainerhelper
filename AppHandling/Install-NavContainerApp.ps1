<# 
 .Synopsis
  Install Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Install-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter appName
  Name of app you want to install in the container
 .Example
  Install-NavApp -containerName test2 -appName myapp
#>
function Install-NavContainerApp {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Installing app $appName"
        Install-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully installed"
}
Export-ModuleMember -Function Install-NavContainerApp
