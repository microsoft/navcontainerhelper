<# 
 .Synopsis
  Unpublish Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Unpublish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to unpublish the app (default navserver)
 .Parameter appName
  Name of app you want to unpublish in the container
 .Parameter uninstall
  Include this parameter if you want to uninstall the app before unpublishing
 .Parameter doNotSaveData
  Include this flag to indicate that you do not wish to save data when uninstalling the app
 .Parameter publisher
  Publisher of the app you want to unpublish
 .Parameter version
  Version of the app you want to unpublish
 .Parameter tenant
  If you specify the uninstall switch, then you can specify the tenant from which you want to uninstall the app
 .Example
  Unpublish-NavContainerApp -containerName test2 -appName myapp
 .Example
  Unpublish-NavContainerApp -containerName test2 -appName myapp -uninstall
#>
function UnPublish-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [switch]$unInstall,
        [switch]$doNotSaveData,
        [Parameter(Mandatory=$false)]
        [string]$publisher,
        [Parameter(Mandatory=$false)]
        [Version]$version,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default"
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName, $unInstall, $tenant, $publisher, $version)
        if ($unInstall) {
            Write-Host "Uninstalling $appName from tenant $tenant"
            $params = @{}
            if ($doNotSaveData)
            {
                $params += @{ "DoNotSaveData" = $true }
            }
            Uninstall-NavApp -ServerInstance NAV -Name $appName -Tenant $tenant @params
        }
        $params = @{}
        if ($publisher) {
            $params += @{ 'Publisher' = $publisher }
        }
        if ($version) {
            $params += @{ 'Version' = $version }
        }
        Write-Host "Unpublishing $appName"
        Unpublish-NavApp -ServerInstance NAV -Name $appName @params
    } -ArgumentList $appName, $unInstall, $tenant, $publisher, $version
    Write-Host -ForegroundColor Green "App successfully unpublished"
}
Export-ModuleMember -Function UnPublish-NavContainerApp
