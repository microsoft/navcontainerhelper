<# 
 .Synopsis
  Repairs App in a NAV/BC Container
 .Description
  Repairs a Business Central App by recompiling it against the current base application. Use this cmdlet if the base application has changed since publishing the Business Central App.
  It is recommended that the Business Central Server instance is restarted after running the repair.
 .Parameter containerName
  Name of the container in which you want to repair an app (default is navserver)
 .Parameter appName
  Name of app you want to repair in the container
 .Parameter appVersion
  Version of app you want to repair in the container
 .Example
  Repair-BcContainerApp -containerName test2 -appName myapp
#>
function Repair-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $appName,
        [Parameter()]
        [string] $appVersion
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion)
        Write-Host "Repairing $appName"
        $parameters = @{
            "ServerInstance" = $ServerInstance;
            "Name" = $appName
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        Repair-NavApp @parameters
    } -ArgumentList $appName, $appVersion
}
Set-Alias -Name Repair-NavContainerApp -Value Repair-BcContainerApp
Export-ModuleMember -Function Repair-BcContainerApp -Alias Repair-NavContainerApp
