<# 
 .Synopsis
  Get a list of folders shared with a NAV/BC Container
 .Description
  Returns a hastable of folders shared with the container.
  The name in the hashtable is the local folder, the value is the folder inside the container
 .Parameter containerName
  Name of the container for which you want to get the shared folder list
 .Example
  Get-BcContainerSharedFolders -containerName bcserver
 .Example
  (Get-BcContainerSharedFolders -containerName bcserver)["c:\programdata\bccontainerhelper"]
 .Example
  ((Get-BcContainerSharedFolders -containerName bcserver).GetEnumerator() | Where-Object { $_.Value -eq "c:\run\my" }).Key
#>
function Get-BcContainerSharedFolders {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $inspect = docker inspect $containerName | ConvertFrom-Json
    $sharedFolders = @{}
    if ($inspect.HostConfig.Binds) {
        $inspect.HostConfig.Binds | ForEach-Object {
            $idx = $_.IndexOf(':', 2)
            $src = $_.Substring(0, $idx).TrimEnd('\')
            $dst = $_.SubString($idx+1)
            $idx = $dst.IndexOf(':', 2)
            if ($idx -gt 0) {
                $dst = $dst.SubString(0,$idx)
            }
            $sharedFolders += @{ $src = $dst }
        }
    }
    
    if ($inspect.Mounts) {
        $inspect.Mounts | ForEach-Object {
            $src = $_.Source
            $dst = $_.Destination
            if (-not ($sharedFolders[$src])) {
                $sharedFolders += @{ $src = $dst }
            }
        }
    }
    return $sharedFolders
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Get-NavContainerSharedFolders -Value Get-BcContainerSharedFolders
Export-ModuleMember -Function Get-BcContainerSharedFolders -Alias Get-NavContainerSharedFolders
