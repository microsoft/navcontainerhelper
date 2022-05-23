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
        [String] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $keyName,
        [Parameter(Mandatory=$true)]
        [string] $keyValue
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{
        Param($keyName, $keyValue)
        Get-NavServerInstance | Set-NAVServerConfiguration -KeyName $keyName -KeyValue $keyValue
    } -argumentList $keyName, $keyValue | Out-Null
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
