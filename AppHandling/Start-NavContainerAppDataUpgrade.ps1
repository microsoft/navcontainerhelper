<# 
 .Synopsis
  Upgrade App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Start-NAVAppDataUpgrade in the container
 .Parameter containerName
  Name of the container in which you want to upgrade the app (default navserver)
 .Parameter appName
  Name of app you want to upgrade in the container
 .Example
  Start-NavContainerAppDataUpgrade -containerName test2 -appName myapp
#>
function  Start-NavContainerAppDataUpgrade {
    Param(
        [string] $containerName = "navserver",
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $appName,
        [Parameter(Mandatory=$false)]

        [string] $appVersion
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant)
        Write-Host "Upgrading app $appName"
        $parameters = @{
            "ServerInstance" = $ServerInstance;
            "Name" = $appName;
            "Tenant" = $tenant
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        Start-NAVAppDataUpgrade @parameters
    } -ArgumentList $appName, $appVersion, $tenant
    Write-Host -ForegroundColor Green "App successfully upgraded"
}
Set-Alias -Name Start-BCContainerAppDataUpgrade -Value Start-NavContainerAppDataUpgrade
Export-ModuleMember -Function Start-NavContainerAppDataUpgrade -Alias Start-BCContainerAppDataUpgrade
