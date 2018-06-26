<# 
 .Synopsis
  Remove Nav container
 .Description
  Remove container, Session, Shortcuts, temp. files and entries in the hosts file,
 .Parameter containerName
  Name of the container you want to remove
 .Parameter updateHosts
  Include this switch if you want to update the hosts file and remove the container entry
 .Example
  Remove-NavContainer -containerName devServer
 .Example
  Remove-NavContainer -containerName test -updateHosts
#>
function Remove-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [string]$containerName
    )

    Process {
        if (Test-NavContainer -containerName $containerName) {
            Remove-NavContainerSession $containerName
            $containerId = Get-NavContainerId -containerName $containerName
            Write-Host "Removing container $containerName"
            docker rm $containerId -f | Out-Null
        }
        $containerFolder = Join-Path $ExtensionsFolder $containerName
        $updateHostsScript = Join-Path $containerFolder "my\updatehosts.ps1"
        $updateHosts = Test-Path -Path $updateHostsScript -PathType Leaf
        if ($updateHosts) {
            Write-Host "Removing $containerName from hosts"
            . $updateHostsScript -hostsFile "c:\windows\system32\drivers\etc\hosts" -hostname $containerName -ipAddress ""
        }
        if (Test-Path -Path $containerFolder -PathType Container) {
            Write-Host "Removing $containerFolder"
            Remove-Item -Path $containerFolder -Force -Recurse
        }
        Remove-DesktopShortcut -Name "$containerName Web Client"
        Remove-DesktopShortcut -Name "$containerName Test Tool"
        Remove-DesktopShortcut -Name "$containerName Windows Client"
        Remove-DesktopShortcut -Name "$containerName CSIDE"
        Remove-DesktopShortcut -Name "$containerName Command Prompt"
        Remove-DesktopShortcut -Name "$containerName PowerShell Prompt"
    }
}
Export-ModuleMember -function Remove-NavContainer
