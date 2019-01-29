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
        [string]$appName,
        [Parameter()]
        [string]$appVersion,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Add','Clean')]
        $Mode
    )
    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName,$appVersion,$tenant,$mode)
        Write-Host "Synchronizing $appFile on $tenant"
        Sync-NavTenant -ServerInstance NAV -Tenant $tenant -Force
        $parameters = @{
            "ServerInstance" = "NAV";
            "Name" = $appName;
            "Tenant" = $tenant
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        if ($mode)
        {
            $parameters += @{ "Mode" = $mode }
        }
        Sync-NavApp @parameters
    } -ArgumentList $appName, $appVersion, $tenant, $Mode
    Write-Host -ForegroundColor Green "App successfully synchronized"
}
Export-ModuleMember -Function Sync-NavContainerApp
