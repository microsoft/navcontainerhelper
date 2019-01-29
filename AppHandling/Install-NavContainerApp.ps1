<# 
 .Synopsis
  Install Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Install-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter appName
  Name of app you want to install in the container
 .Example
  Install-NavContainerApp -containerName test2 -appName myapp
#>
function Install-NavContainerApp {
    Param
    (
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
        Write-Host "Installing $appName on $tenant"
        $parameters = @{ 
            "ServerInstance" = "NAV";
            "Name" = $appName; 
            "Tenant" = $tenant
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        Install-NavApp @parameters
    } -ArgumentList $appName, $appVersion, $tenant
    Write-Host -ForegroundColor Green "App successfully installed"
}
Export-ModuleMember -Function Install-NavContainerApp
