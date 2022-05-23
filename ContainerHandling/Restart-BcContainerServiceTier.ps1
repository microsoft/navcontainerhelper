<# 
 .Synopsis
  Restarts a Business Central Server instance inside of an Business Central Container.
 .Description
  The Restart-BcContainerServiceTier cmldet stops a server instance, and then starts it again.
  You will typically use the Restart-BcContainerServiceTier cmdlet after you make changes to the 
  server instance configuration using the Set-BcContainerServerConfiguration cmdlet, because most 
  configuration changes will not take effect until the server instance is restarted.

  Be aware that when you restart the server instance, all client connections to the server instance are terminated.
 .Parameter containerName
  Name of container which Business Central Server you want to restart
 .Example
  Restart-BcContainerServiceTier -containerName "MyContainer"
#>
function Restart-BcContainerServiceTier {
    Param (
        [String] $ContainerName = $bcContainerHelperConfig.defaultContainerName
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{
        Get-NavServerInstance | Restart-NAVServerInstance
    } | Out-Null
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Restart-BcContainerServiceTier
