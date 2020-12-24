<# 
 .Synopsis
  Uninstall App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Uninstall-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to uninstall the app
 .Parameter tenant
  Name of the tenant in which you want to uninstall the app (default default)
 .Parameter appName
  Name of app you want to uninstall in the container
 .Parameter appVersion
  Version of app you want to uninstall in the container
 .Parameter doNotSaveData
  Include this flag to indicate that you do not wish to save data when uninstalling the app
 .Parameter doNotSaveSchema
  Include this flag to indicate that you do not wish to save database schema when uninstalling the app
 .Parameter force
  Include this flag to indicate that you want to force uninstall the app
 .Example
  Uninstall-BcContainerApp -containerName test2 -name myapp
 .Example
  Uninstall-BcContainerApp -containerName test2 -name myapp -doNotSaveData
#>
function UnInstall-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Alias("appName")]
        [Parameter(Mandatory=$true)]
        [string] $name,
        [Parameter(Mandatory=$false)]
        [Alias("appPublisher")]
        [string] $publisher,
        [Alias("appVersion")]
        [Parameter(Mandatory=$false)]
        [string] $version,
        [switch] $doNotSaveData,
        [switch] $doNotSaveSchema,
        [switch] $Force
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($name, $publisher, $version, $tenant, $doNotSaveData, $doNotSaveSchema, $Force)
        Write-Host "Uninstalling $name from $tenant"
        $parameters = @{
            "ServerInstance" = $ServerInstance
            "Name" = $name
            "Tenant" = $tenant
        }
        if ($publisher) {
            $parameters += @{ "Publisher" = $publisher }
        }
        if ($version) {
            $parameters += @{ "Version" = $version }
        }
        if ($Force) {
            $parameters += @{ "Force" = $true }
        }
        if ($doNotSaveData) {
            Uninstall-NavApp @parameters -doNotSaveData
            if ($doNotSaveSchema) {
                Write-Host "Cleaning Schema from $name on $tenant"
                Sync-NAVApp $parameters -mode Clean
            }
        }
        else {
            Uninstall-NavApp @parameters
        }

    } -ArgumentList $name, $publisher, $version, $tenant, $doNotSaveData, $doNotSaveSchema, $Force
    Write-Host -ForegroundColor Green "App successfully uninstalled"
}
Set-Alias -Name UnInstall-NavContainerApp -Value UnInstall-BcContainerApp
Export-ModuleMember -Function UnInstall-BcContainerApp -Alias UnInstall-NavContainerApp
