<# 
 .Synopsis
  Remove a PSSession for a NAV/BC Container
 .Description
  If a session exists in the session cache, it will be removed and disposed.
  Remove-BcContainer automatically removes sessions created.
 .Parameter containerName
  Name of the container for which you want to remove the session
 .Example
  Remove-BcContainerSession -containerName navserver
#>
function Remove-BcContainerSession {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    Process {
        $containerId = Get-BcContainerId -containerName $containerName

        if ($sessions.ContainsKey($containerId)) {
            $session = $sessions[$containerId]
            Remove-PSSession -Session $session
            $sessions.Remove($containerId)
        }
    }
}
Set-Alias -Name Remove-NavContainerSession -Value Remove-BcContainerSession
Export-ModuleMember -Function Remove-BcContainerSession -Alias Remove-NavContainerSession
