<# 
 .Synopsis
  Copy an item (file or folder) from the host system to a container.
 .Description
  Copy an item (file or folder) from the host system to a container.
 .Parameter containerName
  Name of the container to which you want to copy the item.
 .Parameter localPath
  Path to the item on the host system which has to be copied.
 .Parameter containerPath
  Path in the container where the item will be placed.
  If the source item is a folder, 'containerPath' will be created (or treated) as a folder and all items inside the source folder will be copied to it.
 .Example
  Copy-ItemToBcContainer -containerName test2 -localPath "c:\build" -containerPath "c:\temp\build"
#>
function Copy-ItemToBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory = $true)]
        [string] $localPath,
        [Parameter(Mandatory = $false)]
        [string] $containerPath = $localPath
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        if (!(Test-BcContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Write-Host "Copy '$localPath' from host to '$containerPath' on container $containerName"

        $tempItem = Join-Path $bcContainerHelperConfig.hostHelperFolder ([GUID]::NewGuid().ToString())
        try {
            Copy-Item -Path $localPath -Destination $tempItem -Recurse
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { 
                param($tempItem, $containerPath)
                if ([IO.Directory]::Exists($tempItem)) {
                    # item to copy is a folder
                    [IO.Directory]::CreateDirectory($containerPath) | Out-Null
                    Get-ChildItem $tempItem | Copy-Item -Destination $containerPath -Force -Recurse
                }
                else {
                    # item to copy is a file
                    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($containerPath)) | Out-Null
                    Move-Item -Path $tempItem -Destination $containerPath -Force
                }
            } -argumentList (Get-BcContainerPath -containerName $containerName -Path $tempItem), $containerPath
        }
        finally {
            if (Test-Path $tempItem) {
                Remove-Item $tempItem -ErrorAction Ignore -Recurse
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

Export-ModuleMember Copy-ItemToBcContainer