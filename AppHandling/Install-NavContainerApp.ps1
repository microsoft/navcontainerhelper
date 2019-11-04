<# 
 .Synopsis
  Install App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Install-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter tenant
  Name of the tenant in which you want to install the app (default default)
 .Parameter appName
  Name of app you want to install in the container
 .Parameter appVersion
  Versin of app you want to install in the container
 .Example
  Install-NavContainerApp -containerName test2 -appName myapp
#>
function Install-NavContainerApp {
    Param (
        [string] $containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [string] $appName,
        [Parameter()]
        [string] $appVersion
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant)
        Write-Host "Installing $appName on $tenant"
        $parameters = @{ 
            "ServerInstance" = $ServerInstance
            "Name" = $appName
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
Set-Alias -Name Install-BCContainerApp -Value Install-NavContainerApp
Export-ModuleMember -Function Install-NavContainerApp -Alias Install-BCContainerApp
