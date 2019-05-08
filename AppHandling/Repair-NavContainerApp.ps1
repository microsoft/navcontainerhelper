<# 
 .Synopsis
  Repairs Nav App in a Nav container
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
  Repair-NavContainerApp -containerName test2 -appName myapp
#>
function Repair-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [Parameter()]
        [string]$appVersion
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion)
        Write-Host "Repairing $appName"
        $parameters = @{
            "ServerInstance" = "NAV";
            "Name" = $appName
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        Repair-NavApp @parameters
    } -ArgumentList $appName, $appVersion
}
Export-ModuleMember -Function Repair-NavContainerApp
