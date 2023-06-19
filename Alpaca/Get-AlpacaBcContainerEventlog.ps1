<#
 .SYNOPSIS
  Download Eventlog from Alpaca BC Container
 .DESCRIPTION
  Download Eventlog from Alpaca BC Container
 .PARAMETER authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container Id of the Alpaca container from which to download the eventlog.
 .EXAMPLE
  Get-AlpacaBcContainerEventlog -authContext $authContext -containerId $containerId
#>
function Get-AlpacaBcContainerEventLog {
    Param (
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [switch] $doNotOpen
    )
    
    Write-Host "Getting event log for $containerId"

    $eventLogFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "EventLogs"
    if (!(Test-Path $eventLogFolder)) {
        New-Item $eventLogFolder -ItemType Directory | Out-Null
    }
    $eventLogName = Join-Path $eventLogFolder ($containerId + ' ' + [DateTime]::Now.ToString("yyyy-MM-dd HH.mm.ss") + ".evtx")

    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Task/$containerId/eventlog"
    Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -OutFile $eventLogName
    if ($doNotOpen) {
        $eventLogName
    }
    else {
        [Diagnostics.Process]::Start($eventLogName) | Out-Null
    }
}
Export-ModuleMember Get-AlpacaBcContainerEventLog
