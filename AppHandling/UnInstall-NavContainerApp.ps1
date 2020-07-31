<# 
 .Synopsis
  Uninstall App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Uninstall-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to uninstall the app (default navserver)
 .Parameter tenant
  Name of the tenant in which you want to uninstall the app (default default)
 .Parameter appName
  Name of app you want to uninstall in the container
 .Parameter appVersion
  Version of app you want to uninstall in the container
 .Parameter doNotSaveData
  Include this flag to indicate that you do not wish to save data when uninstalling the app
 .Parameter force
  Include this flag to indicate that you want to force uninstall the app
 .Example
  Uninstall-BcContainerApp -containerName test2 -appName myapp
 .Example
  Uninstall-BcContainerApp -containerName test2 -appName myapp -doNotSaveData
#>
function UnInstall-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $appName,
        [Parameter(Mandatory=$false)]
        [string] $appVersion,
        [switch] $doNotSaveData,
        [switch] $Force
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant, $doNotSaveData, $Force)
        Write-Host "Uninstalling $appName from $tenant"
        $parameters = @{
            "ServerInstance" = $ServerInstance
            "Name" = $appName
            "Tenant" = $tenant
        }
        if ($appVersion) {
            $parameters += @{ "Version" = $appVersion }
        }
        if ($doNotSaveData) {
            $parameters += @{ "DoNotSaveData" = $true }
        }
        if ($Force) {
            $parameters += @{ "Force" = $true }
        }
        Uninstall-NavApp @parameters
    } -ArgumentList $appName, $appVersion, $tenant, $doNotSaveData, $Force
    Write-Host -ForegroundColor Green "App successfully uninstalled"
}
Set-Alias -Name UnInstall-NavContainerApp -Value UnInstall-BcContainerApp
Export-ModuleMember -Function UnInstall-BcContainerApp -Alias UnInstall-NavContainerApp
