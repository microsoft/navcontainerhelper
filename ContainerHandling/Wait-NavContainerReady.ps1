<# 
 .Synopsis
  Wait for NAV/BC Container to become ready
 .Description
  Wait for container to log "Ready for connections!"
  If the container experiences an error, the function will throw an exception
 .Parameter containerName
  Name of the container for which you want to wait
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.). -1 means wait forever.
 .Example
  Wait-BcContainerReady -containerName bcserver
#>
function Wait-BcContainerReady {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [int] $timeout = 1800,
        [string] $startlog = ""
    )

    Process {
        $logs = docker logs $containerName
        $prevLog = ""
        Write-Host "Waiting for container $containerName to be ready"
        $cnt = $timeout
        $log = ""
        do {
            Start-Sleep -Seconds 1
            $logs = docker logs $containerName
            if ($logs) { $log = ([string]::Join("`r`n",$logs)).substring($startLog.Length) }
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

            if ($cnt % 5 -eq 0) {
                $inspect = docker inspect $containerName | ConvertFrom-Json
                if ($inspect.State.Status -eq "exited") {
                    Write-Host "Error"
                    Write-Host "Container Exited, ExitCode $($inspect.State.ExitCode)"
                    throw "Initialization of container $containerName failed"
                }
            }

        } while (!($log.Contains("Ready for connections!")))
        Write-Host
        if ($bcContainerHelperConfig.usePsSession) {
            try {
                Write-Host "create new session"
                Get-BcContainerSession -containerName $containerName -reinit
            } catch {}
        }

        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
            $boo = $true
            while (Get-NAVServerInstance | Get-NavTenant | Where-Object { $_.State -eq "Mounting" }) {
                if ($boo) { Write-Host "Waiting for tenants to be mounted"; $boo = $false }
                Start-Sleep -Seconds 1
            }
        }
    
    }
}
Set-Alias -Name Wait-NavContainerReady -Value Wait-BcContainerReady
Export-ModuleMember -Function Wait-BcContainerReady -Alias Wait-NavContainerReady
