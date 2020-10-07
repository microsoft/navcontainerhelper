<# 
 .Synopsis
  Sync App in container
 .Description
  Creates a session to the container and runs the CmdLet Sync-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to sync the app
 .Parameter tenant
  Name of the tenant in which you want to sync the app
 .Parameter appName
  Name of app you want to sync in the container
 .Parameter appPublisher
  Publisher of app you want to sync in the container
 .Parameter appVersion
  Version of app you want to sync in the container
 .Parameter mode
  Sync mode to transfer to Sync-NavApp
 .Example
  Sync-BcContainerApp -containerName test2 -appName myapp
#>
function Sync-BcContainerApp {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $appName,
        [string] $appPublisher,
        [string] $appVersion,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Add','Clean','ForceSync')]
        [string] $Mode,
        [switch] $Force
    )
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName,$appPublisher,$appVersion,$tenant,$mode,$force)
        Write-Host "Synchronizing $appName on $tenant"
        Sync-NavTenant -ServerInstance $ServerInstance -Tenant $tenant -Force
        $parameters = @{
            "ServerInstance" = $ServerInstance
            "Name" = $appName
            "Tenant" = $tenant
        }
        if ($appPublisher) {
            $parameters += @{ "Publisher" = $appPublisher }
        }
        if ($appVersion) {
            $parameters += @{ "Version" = $appVersion }
        }
        if ($mode) {
            $parameters += @{ "Mode" = $mode }
        }
        if ($force) {
            $parameters += @{ "Force" = $true }
        }
        Sync-NavApp @parameters
    } -ArgumentList $appName, $appPublisher, $appVersion, $tenant, $Mode, $force
    Write-Host -ForegroundColor Green "App successfully synchronized"
}
Set-Alias -Name Sync-NavContainerApp -Value Sync-BcContainerApp
Export-ModuleMember -Function Sync-BcContainerApp -Alias Sync-NavContainerApp
