<# 
 .Synopsis
  Configures settings for a Business Central Server instance.  
 .Description
  Use the Set-BcContainerServerConfiguration cmdlet to configure settings for a Business Central Server instance. 
  Changes to just the configuration file will first take effect when the server instance is restarted.
 .Parameter containerName
  Name of the container for which you want to get the server configuration
 .Parameter KeyName
  Key of the container for which you want to get the server configuration
 .Parameter KeyValue
  Value of the container for which you want to get the server configuration
 .Example
  Set-BcContainerServerConfiguration -ContainerName "MyContainer" -KeyName "EnableTaskScheduler" -KeyValue "true"
#>
Function Set-BcContainerServerConfiguration {
    Param (
        [String] $ContainerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $KeyName,
        [Parameter(Mandatory=$true)]
        [string] $KeyValue
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $ResultObjectArray = @()
    $config = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{
        Get-NavServerInstance | Set-NAVServerConfiguration -KeyName $KeyName -KeyValue $KeyValue
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Set-BcContainerServerConfiguration
