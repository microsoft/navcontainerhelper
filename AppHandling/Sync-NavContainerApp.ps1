<# 
 .Synopsis
  Sync App in container
 .Description
  Creates a session to the container and runs the CmdLet Sync-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter appName
  Name of app you want to sync in the container
 .Example
  Sync-NavContainerApp -containerName test2 -appName myapp
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
        Sync-NavTenant -ServerInstance $ServerInstance -Tenant $tenant -Force
        $parameters = @{
            "ServerInstance" = $ServerInstance;
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
Set-Alias -Name Sync-BCContainerApp -Value Sync-NavContainerApp
Export-ModuleMember -Function Sync-NavContainerApp -Alias Sync-BCContainerApp
