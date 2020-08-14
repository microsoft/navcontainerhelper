<# 
 .Synopsis
  Install App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Install-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app
 .Parameter tenant
  Name of the tenant in which you want to install the app (default default)
 .Parameter appName
  Name of app you want to install in the container
 .Parameter appVersion
  Versin of app you want to install in the container
 .Parameter force
  Include this flag to indicate that you want to force install the app
 .Example
  Install-BcContainerApp -containerName test2 -appName myapp
#>
function Install-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory = $false)]
        [string] $tenant = "default",
        [Parameter(Mandatory = $true)]
        [string] $appName,
        [Parameter()]
        [string] $appVersion,
        [switch] $Force
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant, $Force)
        Write-Host "Installing $appName on $tenant"
        $parameters = @{ 
            "ServerInstance" = $ServerInstance
            "Name"           = $appName
            "Tenant"         = $tenant
            "Force"          = $Force
        }
        if ($appVersion) {
            $parameters += @{ "Version" = $appVersion }
        }
        Install-NavApp @parameters
    } -ArgumentList $appName, $appVersion, $tenant, $Force
    Write-Host -ForegroundColor Green "App successfully installed"
}
Set-Alias -Name Install-NavContainerApp -Value Install-BcContainerApp
Export-ModuleMember -Function Install-BcContainerApp -Alias Install-NavContainerApp
