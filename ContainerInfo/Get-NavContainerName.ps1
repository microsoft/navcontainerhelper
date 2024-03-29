﻿<# 
 .Synopsis
  Get the name of a NAV/BC Container
 .Description
  Returns the name of a Container based on the container Id
  You need to specify enought characters of the Id to make it unambiguous
 .Parameter containerId
  Id (or part of the Id) of the container for which you want to get the name
 .Example
  Get-BcContainerName -containerId 7d
#>
function Get-BcContainerName {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    docker ps --format='{{.Names}}' -a --filter "id=$containerId"
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Get-NavContainerName -Value Get-BcContainerName
Export-ModuleMember -Function Get-BcContainerName -Alias Get-NavContainerName
