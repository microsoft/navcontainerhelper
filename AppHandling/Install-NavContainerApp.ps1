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
  Install-NavContainerApp -containerName test2 -appName myapp
#>
function Install-NavContainerApp {
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName, $tenant)
        Write-Host "Installing $appName on $tenant"
        Install-NavApp -ServerInstance NAV -Name $appName -Tenant $tenant
    } -ArgumentList $appName, $tenant
    Write-Host -ForegroundColor Green "App successfully installed"
}
Export-ModuleMember -Function Install-NavContainerApp
