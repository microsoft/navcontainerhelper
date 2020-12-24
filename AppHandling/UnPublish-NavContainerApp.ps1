<# 
 .Synopsis
  Unpublish App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Unpublish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to unpublish the app
 .Parameter appName
  Name of app you want to unpublish in the container
 .Parameter uninstall
  Include this parameter if you want to uninstall the app before unpublishing
 .Parameter doNotSaveData
  Include this flag to indicate that you do not wish to save data when uninstalling the app
 .Parameter doNotSaveSchema
  Include this flag to indicate that you do not wish to save database schema when uninstalling the app
 .Parameter force
  Include this flag to indicate that you want to force uninstall the app
 .Parameter publisher
  Publisher of the app you want to unpublish
 .Parameter version
  Version of the app you want to unpublish
 .Parameter tenant
  If you specify the uninstall switch, then you can specify the tenant from which you want to uninstall the app
 .Example
  Unpublish-BcContainerApp -containerName test2 -name myapp
 .Example
  Unpublish-BcContainerApp -containerName test2 -name myapp -uninstall
#>
function UnPublish-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Alias("appName")]
        [Parameter(Mandatory=$true)]
        [string] $name,
        [Alias("appPublisher")]
        [Parameter(Mandatory=$false)]
        [string] $publisher,
        [Alias("appVersion")]
        [Parameter(Mandatory=$false)]
        [string] $version,
        [switch] $unInstall,
        [switch] $doNotSaveData,
        [switch] $doNotSaveSchema,
        [switch] $force
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($name, $unInstall, $tenant, $publisher, $version, $doNotSaveData, $doNotSaveSchema, $force)
        if ($unInstall) {
            Write-Host "Uninstalling $name from tenant $tenant"
            $params = @{}
            if ($publisher) {
                $params += @{ 'Publisher' = $publisher }
            }
            if ($version) {
                $params += @{ 'Version' = $version }
            }
            if ($doNotSaveData) {
                $params += @{ "DoNotSaveData" = $true }
            }
            if ($force) {
                $params += @{ "force" = $true }
            }
            Uninstall-NavApp -ServerInstance $ServerInstance -Name $name -Tenant $tenant @params
            if ($doNotSaveData -and $doNotSaveSchema) {
                Write-Host "Cleaning Schema from $name on $tenant"
                Sync-NAVApp -ServerInstance $ServerInstance -Name $name -Tenant $tenant -mode Clean -force:$force
            }
        }
        $params = @{}
        if ($publisher) {
            $params += @{ 'Publisher' = $publisher }
        }
        if ($version) {
            $params += @{ 'Version' = $version }
        }
        $appInfo = (Get-NAVAppInfo -ServerInstance $ServerInstance -Name $name @params)
        if ([bool]($appInfo.PSObject.Properties.Name -eq 'Scope')) {
            if ($appInfo.Scope -eq "Tenant") {
                $params += @{ 'Tenant' = $tenant }
            }
        }

        Write-Host "Unpublishing $name"
        Unpublish-NavApp -ServerInstance $ServerInstance -Name $name @params
    } -ArgumentList $name, $unInstall, $tenant, $publisher, $version, $doNotSaveData, $doNotSaveSchema, $force
    Write-Host -ForegroundColor Green "App successfully unpublished"
}
Set-Alias -Name UnPublish-NavContainerApp -Value UnPublish-BcContainerApp
Export-ModuleMember -Function UnPublish-BcContainerApp -Alias UnPublish-NavContainerApp
