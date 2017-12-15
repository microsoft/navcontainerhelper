<# 
 .Synopsis
  Wait for Nav container to become ready
 .Description
  Wait for Nav container to log "Ready for connections!"
  If the container experiences an error, the function will throw an exception
 .Parameter containerName
  Name of the container for which you want to wait
 .Example
  Wait-NavContainerReady -containerName navserver
#>
function Wait-NavContainerReady {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [int]$timeout = 60
    )

    Process {
        $prevLog = ""
        Write-Host "Waiting for container $containerName to be ready"
        $cnt = $timeout
        $log = ""
        do {
            Start-Sleep -Seconds 1
            $logs = docker logs $containerName
            if ($logs) { $log = [string]::Join("`r`n",$logs) }
            $newLog = $log.subString($prevLog.Length)
            $prevLog = $log
            if ($newLog -ne "") {
                $cnt = $timeout
                Write-Host -NoNewline $newLog
            }

            if ($cnt-- -eq 0 -or $log.Contains("<ScriptBlock>")) { 
                Write-Host "Error"
                Write-Host $log
                throw "Initialization of container $containerName failed"
            }
        } while (!($log.Contains("Ready for connections!")))
        Write-Host
    }
}
Export-ModuleMember -function Wait-NavContainerReady
