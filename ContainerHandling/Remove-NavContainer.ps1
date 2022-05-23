<# 
 .Synopsis
  Remove a NAV/BC Container
 .Description
  Remove container, Session, Shortcuts, temp. files and entries in the hosts file,
 .Parameter containerName
  Name of the container you want to remove
 .Example
  Remove-BcContainer -containerName devServer
#>
function Remove-BcContainer {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $hostname = ""
    if (Test-BcContainer -containerName $containerName) {
        try {
            $id = Get-BcContainerId -containerName $containerName
            if ($id) {
                $inspect = docker inspect $id | ConvertFrom-Json
                $hostname = $inspect.config.Hostname
            }
        }
        catch {
            $hostname = ""
        }
        Write-Host "Removing Session $containerName"
        Remove-BcContainerSession $containerName
        $containerId = Get-BcContainerId -containerName $containerName
        Write-Host "Removing container $containerName"
        docker rm $containerId -f | Out-Null
    }
    if ($containerName) {
        if ($hostname -eq "") {
            $hostname = $containerName
        }
        $dotidx = $hostname.indexOf('.')
        if ($dotidx -eq -1) { $dotidx = $hostname.Length }
        $tenantHostname = $hostname.insert($dotidx,"-*")

        $containerFolder = Join-Path $ExtensionsFolder $containerName
        $allVolumes = @(docker volume ls --format "{{.Mountpoint}}|{{.Name}}")
        $myVolumeName = "$containerName-my"
        $myVolume = $allVolumes | Where-Object { $_ -like "*|$myVolumeName" }
        if ($myVolume) {
            $myFolder = $myVolume.Split('|')[0]
        }
        else {
            $myFolder = Join-Path $containerFolder "my"
        }

        $updateHostsScript = Join-Path $myFolder "updatehosts.ps1"
        $updateHosts = Test-Path -Path $updateHostsScript -PathType Leaf
        if ($updateHosts) {
            Write-Host "Removing entries from hosts"
            . (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\windows\system32\drivers\etc\hosts" -theHostname $hostname -theIpAddress ""
            . (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\windows\system32\drivers\etc\hosts" -theHostname $tenantHostname -theIpAddress ""
        }

        if ($myVolume) {
            Write-Host "Removing volume $myVolumeName"
            docker volume remove $myVolumeName
        }

        $thumbprintFile = Join-Path $containerFolder "thumbprint.txt"
        if (Test-Path -Path $thumbprintFile) {
            $thumbprint = Get-Content -Path $thumbprintFile
            $cert = Get-ChildItem "cert:\localMachine\Root" | Where-Object { $_.Thumbprint -eq $thumbprint }
            if ($cert) {
                try {
                    $cert | Remove-Item
                    Write-Host "Certificate with thumbprint $thumbprint removed successfully"
                }
                catch {
                    Write-Host -ForegroundColor Yellow "Unable to remove certificate $thumbprint, you will need to do this manually"
                }
            }
            else {
                Write-Host "Certificate with thumbprint $thumbprint not found in store"
            }
        }

        Write-Host "Removing Desktop shortcuts"
        Remove-DesktopShortcut -Name "$containerName Web Client"
        Remove-DesktopShortcut -Name "$containerName Performance Tool"
        Remove-DesktopShortcut -Name "$containerName Test Tool"
        Remove-DesktopShortcut -Name "$containerName Windows Client"
        Remove-DesktopShortcut -Name "$containerName WinClient Debugger"
        Remove-DesktopShortcut -Name "$containerName CSIDE"
        Remove-DesktopShortcut -Name "$containerName Command Prompt"
        Remove-DesktopShortcut -Name "$containerName PowerShell Prompt"

        if (Test-Path $containerFolder) {
            $wait = 10
            $attempts = 0
            $filesLeft = $true
            Write-Host "Removing $containerFolder"
            while ($filesLeft) {
                $files = @()
                Get-ChildItem $containerfolder -Recurse -File | % {
                    $file = $_.FullName
                    try {
                        Remove-Item $file -Force -ErrorAction stop
                    }
                    catch {
                        $files += $file
                    }
                }
                if ($files.count -eq 0) {
                    $filesLeft = $false
                }
                else {
                    $attempts++
                    if ($attempts -gt 10) {
                        throw "Could not remove $containerFolder"
                    }
                    Write-Host "Error removing $containerFolder (attempts: $attempts)"
                    Write-Host "The following files could not be removed:"
                    $files | % { 
                        Write-Host "- $_"
                    }
                    Write-Host "Please close any apps, prompts or files using these files"
                    Write-Host "Retrying in $wait seconds"
                    Start-Sleep -Seconds $wait
                }
            }
            Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction SilentlyContinue
        }
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
Set-Alias -Name Remove-NavContainer -Value Remove-BcContainer
Export-ModuleMember -Function Remove-BcContainer -Alias Remove-NavContainer
