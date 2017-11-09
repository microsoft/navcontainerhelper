<# 
 .Synopsis
  Remove Nav container
 .Description
  Remove container, Session, Shortcuts, temp. files and entries in the hosts file,
 .Parameter containerName
  Name of the container for which you want to enter a session
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
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [switch]$UpdateHosts
    )

    Process {
        if ($containerName -eq "navserver") {
            throw "You should not remove the navserver container. Use Replace-NavServerContainer to replace the navserver container."
        }

        if (Test-NavContainer -containerName $containerName) {
            Remove-NavContainerSession $containerName
            $containerId = Get-NavContainerId -containerName $containerName
            Write-Host "Removing container $containerName"
            docker rm $containerId -f | Out-Null
            $containerFolder = Join-Path $ExtensionsFolder $containerName
            Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction Ignore
            Write-Host "Removing Desktop Shortcuts for container $containerName"
            Remove-DesktopShortcut -Name "$containerName Web Client"
            Remove-DesktopShortcut -Name "$containerName Windows Client"
            Remove-DesktopShortcut -Name "$containerName CSIDE"
            Remove-DesktopShortcut -Name "$containerName Command Prompt"
            Remove-DesktopShortcut -Name "$containerName PowerShell Prompt"
            if ($UpdateHosts) {
                Write-Host "Remove $containerName from hosts"
                Update-Hosts -hostName $containerName -ip ""
            }
            Write-Host -ForegroundColor Green "Successfully removed container $containerName"
        }
    }
}
Export-ModuleMember -function Remove-NavContainer
