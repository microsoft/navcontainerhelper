<# 
 .Synopsis
  Get the OS Version for a NAV/BC Container or a NAV/BC Container image
 .Description
  Returns the version of the WindowsServerCore image used to build the Container or ContainerImage
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the OS Version
 .Example
  Get-BcContainerOsVersion -containerOrImageName bcserver
 .Example
  Get-BcContainerOsVersion -containerOrImageName microsoft/dynamics-nav:2017
#>
function Get-BcContainerOsVersion {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerOrImageName
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
    return "$($inspect.Config.Labels.osversion)"
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Get-NavContainerOsVersion -Value Get-BcContainerOsVersion
Export-ModuleMember -Function Get-BcContainerOsVersion -Alias Get-NavContainerOsVersion
