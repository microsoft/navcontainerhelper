<# 
 .Synopsis
  Get the Event log from a NAV/BC Container as an .evtx file
 .Description
  Get a copy of the current Event Log from a continer and open it in the local event viewer
 .Parameter containerName
  Name of the container for which you want to get the Event log
 .Parameter logName
  Name of the log you want to get (default is Application)
 .Parameter doNotOpen
  Obtain a copy of the event log, but do not open the event log in the event viewer
 .Example
  Get-BcContainerEventLog -containerName bcserver
 .Example
  Get-BcContainerEventLog -containerName bcserver -logname Security -doNotOpen
#>
function Get-BcContainerEventLog {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $logname = "Application",
        [switch] $doNotOpen
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Write-Host "Getting event log for $containername"

    $eventLogFolder = Join-Path $hostHelperFolder "EventLogs"
    if (!(Test-Path $eventLogFolder)) {
        New-Item $eventLogFolder -ItemType Directory | Out-Null
    }
    $eventLogName = Join-Path $eventLogFolder ($containerName + ' ' + [DateTime]::Now.ToString("yyyy-MM-dd HH.mm.ss") + ".evtx")

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param([string]$path, [string]$logname) 
        wevtutil epl $logname "$path"
    } -ArgumentList (Get-BcContainerPath -containerName $containerName -Path $eventLogName), $logname

    if ($doNotOpen) {
        $eventLogName
    }
    else {
        [Diagnostics.Process]::Start($eventLogName) | Out-Null
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
Set-Alias -Name Get-NavContainerEventLog -Value Get-BcContainerEventLog
Export-ModuleMember -Function Get-BcContainerEventLog -Alias Get-NavContainerEventLog
