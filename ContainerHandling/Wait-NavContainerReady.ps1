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
        [string]$containerName
    )

    Process {
        Write-Host "Waiting for container $containerName to be ready, this shouldn't take more than a few minutes"
        Write-Host "Time:          ½              1              ½              2"
        $cnt = 150
        $log = ""
        do {
            Write-Host -NoNewline "."
            Start-Sleep -Seconds 2
            $logs = docker logs $containerName
            if ($logs) { $log = [string]::Join("`r`n",$logs) }
            if ($cnt-- -eq 0 -or $log.Contains("<ScriptBlock>")) { 
                Write-Host "Error"
                Write-Host $log
                throw "Initialization of container $containerName failed"
            }
        } while (!($log.Contains("Ready for connections!")))
        Write-Host "Ready"
    }
}
Export-ModuleMember -function Wait-NavContainerReady
