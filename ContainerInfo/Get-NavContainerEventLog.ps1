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
  Get-BcContainerEventLog -containerName navserver
 .Example
  Get-BcContainerEventLog -containerName navserver -logname Security -doNotOpen
#>
function Get-BcContainerEventLog {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $logname = "Application",
        [switch] $doNotOpen
    )

    Process {
        Write-Host "Getting event log for $containername"

        $containerFolder = Join-Path $ExtensionsFolder $containerName
        $myFolder = Join-Path $containerFolder "my"
        $folder = Get-BcContainerPath -containerName $containerName -Path $myFolder
        $name = $containerName + ' ' + [DateTime]::Now.ToString("yyyy-MM-dd HH.mm.ss") + ".evtx"
        Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param([string]$path, [string]$logname) 
            wevtutil epl $logname "$path"
        } -ArgumentList (Join-Path $folder $name), $logname

        if (!$doNotOpen) {
            [Diagnostics.Process]::Start((Join-Path -Path $myFolder $name)) | Out-Null
        }
    }
}
Set-Alias -Name Get-NavContainerEventLog -Value Get-BcContainerEventLog
Export-ModuleMember -Function Get-BcContainerEventLog -Alias Get-NavContainerEventLog
