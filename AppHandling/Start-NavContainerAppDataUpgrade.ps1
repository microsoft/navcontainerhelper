<#
 .Synopsis
  Upgrade App in NAV/BC Container
 .Description
  Creates a session to the container and runs the CmdLet Start-NAVAppDataUpgrade in the container
 .Parameter containerName
  Name of the container in which you want to upgrade the app
 .Parameter tenant
  Name of the tenant in which you want to upgrade the app (default default)
 .Parameter appName
  Name of app you want to upgrade in the container
 .Parameter appVersion
  Version of app you want to upgrade in the container
 .Example
  Start-BcContainerAppDataUpgrade -containerName test2 -appName myapp
#>
function  Start-BcContainerAppDataUpgrade {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $tenant = "default",
        [Parameter(Mandatory = $true)]
        [string] $appName,
        [string] $appVersion = "",
        [string] $language = "",
        [string] $exclusiveAccessTicket = "",
        [string] $path = "",
        [switch] $force,
        [switch] $skipVersionCheck,
        [ValidateSet("Add", "Clean", "Development", "ForceSync", "None")]
        [string] $syncMode = ""
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $containerPath = ""
        if ($path) {
            $containerPath = (Get-BcContainerPath -containerName $containerName -path $path -throw)
        }

        Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant, $language, $exclusiveAccessTicket, $containerPath, $syncMode, $force, $skipVersionCheck)
            Write-Host "Upgrading app $appName"
            $parameters = @{
                "ServerInstance" = $ServerInstance;
                "Name"           = $appName;
                "Tenant"         = $tenant
            }
            if ($appVersion) {
                $parameters += @{ "Version" = $appVersion }
            }
            if ($language) {
                $parameters += @{ "Language" = $language }
            }
            if ($exclusiveAccessTicket) {
                $parameters += @{ "ExclusiveAccessTicket" = $exclusiveAccessTicket }
            }
            if ($containerPath) {
                $parameters += @{ "Path" = $containerPath }
            }
            if ($syncMode) {
                $parameters += @{ "SyncMode" = $syncMode }
            }
            if ($force.IsPresent) {
                $parameters += @{ "Force" = $true }
            }
            if ($skipVersionCheck.IsPresent) {
                $parameters += @{ "SkipVersionCheck" = $true }
            }

            Start-NAVAppDataUpgrade @parameters
        } -ArgumentList $appName, $appVersion, $tenant, $language, $exclusiveAccessTicket, $containerPath, $syncMode, $force, $skipVersionCheck
        Write-Host -ForegroundColor Green "App successfully upgraded"
    }
    catch {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
        throw
    }
    finally {
        TrackTrace -telemetryScope $telemetryScope
    }
}
Set-Alias -Name Start-NavContainerAppDataUpgrade -Value Start-BcContainerAppDataUpgrade
Export-ModuleMember -Function Start-BcContainerAppDataUpgrade -Alias Start-NavContainerAppDataUpgrade
