<# 
 .Synopsis
  Upgrade Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Start-NAVAppDataUpgrade in the container
 .Parameter containerName
  Name of the container in which you want to upgrade the app (default navserver)
 .Parameter appName
  Name of app you want to upgrade in the container
 .Example
  Start-NavContainerAppDataUpgrade -containerName test2 -appName myapp
#>
function  Start-NavContainerAppDataUpgrade {
    Param(
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [Parameter()]
        [string]$appVersion
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant)
        Write-Host "Upgrading app $appName"
        $parameters = @{
            "ServerInstance" = "NAV";
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
Export-ModuleMember -Function Start-NavContainerAppDataUpgrade
