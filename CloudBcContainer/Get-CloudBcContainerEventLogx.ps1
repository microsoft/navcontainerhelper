<#
 .SYNOPSIS
  Download Eventlog from Cloud BC Container
 .DESCRIPTION
  Download Eventlog from Cloud BC Container
 .PARAMETER authContext
  Authorization Context for Cloud BC Container
 .PARAMETER containerId
  Container Id of the Cloud BC Container from which to download the eventlog.
 .EXAMPLE
  Get-AlpacaBcContainerEventlog -authContext $authContext -containerId $containerId
#>
function Get-CloudBcContainerEventLog {
    Param (
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [switch] $doNotOpen
    )

    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        Get-AlpacaBcContainerEventLog -authContext $authContext -containerId $containerId -doNotOpen:$doNotOpen
    }
    else {
        Write-Host "Getting event log for $containerId"

        $eventLogFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "EventLogs"
        if (!(Test-Path $eventLogFolder)) {
            New-Item $eventLogFolder -ItemType Directory | Out-Null
        }
        $eventLogName = "$containerId $([DateTime]::Now.ToString("yyyy-MM-dd HH.mm.ss")).evtx"
        $locale = (Get-WinSystemLocale).Name
    
        $content = Invoke-ScriptInCloudBcContainer -authContext $authContext -containerId $containerId -ScriptBlock { Param([string] $eventLogName, [string] $locale)
            $path = Join-Path 'c:\run' $eventLogName
            wevtutil epl Application "$path" | Out-Host
            wevtutil al "$path" /locale:$locale | Out-Host
            [System.IO.File]::ReadAllBytes($path)
        } -ArgumentList $eventLogName, $locale
        $eventLogName = Join-Path $eventLogFolder $eventLogName
        [System.IO.File]::WriteAllBytes($eventLogName, $content)
    
        if ($doNotOpen) {
            $eventLogName
        }
        else {
            [Diagnostics.Process]::Start($eventLogName) | Out-Null
        }
    }
}
Export-ModuleMember -Function Get-CloudBcContainerEventLog
