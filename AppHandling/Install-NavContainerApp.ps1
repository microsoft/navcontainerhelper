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
 .Parameter appPublisher
  Publisher of app you want to install in the container
 .Parameter appVersion
  Version of app you want to install in the container
 .Parameter language
  Specify language version that is used for installing the app. The value must be a valid culture name for a language in Business Central, such as en-US or da-DK. If the specified language does not exist on the Business Central Server instance, then en-US is used.
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
        [string] $appPublisher,
        [string] $appVersion,
        [string] $language = "",
        [switch] $Force
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $appPublisher, $appVersion, $tenant, $language, $Force)
        Write-Host "Installing $appName on $tenant"
        $parameters = @{ 
            "ServerInstance" = $ServerInstance
            "Name"           = $appName
            "Tenant"         = $tenant
            "Force"          = $Force
        }
        if ($appPublisher) {
            $parameters += @{ "Publisher" = $appPublisher }
        }
        if ($appVersion) {
            $parameters += @{ "Version" = $appVersion }
        }
        if ($language) {
            $parameters += @{ "Language" = $language }
        }
        Install-NavApp @parameters
    } -ArgumentList $appName, $appPublisher, $appVersion, $tenant, $language, $Force
    Write-Host -ForegroundColor Green "App successfully installed"
}
Set-Alias -Name Install-NavContainerApp -Value Install-BcContainerApp
Export-ModuleMember -Function Install-BcContainerApp -Alias Install-NavContainerApp
