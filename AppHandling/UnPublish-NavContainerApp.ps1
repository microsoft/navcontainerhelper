<# 
 .Synopsis
  Unpublish App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Unpublish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to unpublish the app (default navserver)
 .Parameter appName
  Name of app you want to unpublish in the container
 .Parameter uninstall
  Include this parameter if you want to uninstall the app before unpublishing
 .Parameter doNotSaveData
  Include this flag to indicate that you do not wish to save data when uninstalling the app
 .Parameter force
  Include this flag to indicate that you want to force uninstall the app
 .Parameter publisher
  Publisher of the app you want to unpublish
 .Parameter version
  Version of the app you want to unpublish
 .Parameter tenant
  If you specify the uninstall switch, then you can specify the tenant from which you want to uninstall the app
 .Example
  Unpublish-BcContainerApp -containerName test2 -appName myapp
 .Example
  Unpublish-BcContainerApp -containerName test2 -appName myapp -uninstall
#>
function UnPublish-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $appName,
        [switch] $unInstall,
        [switch] $doNotSaveData,
        [switch] $force,
        [Parameter(Mandatory=$false)]
        [string] $publisher,
        [Parameter(Mandatory=$false)]
        [string] $version,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default"
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $unInstall, $tenant, $publisher, $version, $doNotSaveData, $force)
        if ($unInstall) {
            Write-Host "Uninstalling $appName from tenant $tenant"
            $params = @{}
            if ($doNotSaveData) {
                $params += @{ "DoNotSaveData" = $true }
            }
            if ($force) {
                $params += @{ "force" = $true }
            }
            Uninstall-NavApp -ServerInstance $ServerInstance -Name $appName -Tenant $tenant @params
        }
        $params = @{}
        if ($publisher) {
            $params += @{ 'Publisher' = $publisher }
        }
        if ($version) {
            $params += @{ 'Version' = $version }
        }
        Write-Host "Unpublishing $appName"
        Unpublish-NavApp -ServerInstance $ServerInstance -Name $appName @params
    } -ArgumentList $appName, $unInstall, $tenant, $publisher, $version, $doNotSaveData, $force
    Write-Host -ForegroundColor Green "App successfully unpublished"
}
Set-Alias -Name UnPublish-NavContainerApp -Value UnPublish-BcContainerApp
Export-ModuleMember -Function UnPublish-BcContainerApp -Alias UnPublish-NavContainerApp
