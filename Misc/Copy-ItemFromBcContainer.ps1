<# 
 .Synopsis
  Copy an item (file or folder) from a container to the host system.
 .Description
  Copy an item (file or folder) from a container to the host system.
 .Parameter containerName
  Name of the container from which you want to copy the item.
 .Parameter containerPath
  Path to the item in the container which has to be copied.
 .Parameter localPath
  Path on the host where the item will be placed.
  If the source item is a folder, 'localPath' will be created (or treated) as a folder and all items inside the source folder will be copied to it.
 .Example
  Copy-ItemFromBcContainer -containerName test2 -containerPath "c:\temp\build" -localPath "c:\temp\build-copy"
#>
function Copy-ItemFromBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory = $true)]
        [string] $containerPath,
        [Parameter(Mandatory = $true)]
        [string] $localPath
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        if (!(Test-BcContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Write-Host "Copy '$containerPath' from container $containerName to '$localPath' on host"

        $tempItem = Join-Path $bcContainerHelperConfig.hostHelperFolder ([GUID]::NewGuid().ToString())
        try {
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { 
                param($containerPath, $tempItem)
                Copy-Item -Path $containerPath -Destination $tempItem -Recurse
            } -argumentList $containerPath, (Get-BcContainerPath -containerName $containerName -Path $tempItem)
            if ([IO.Directory]::Exists($tempItem)) {
                # item to copy is a folder
                [IO.Directory]::CreateDirectory($localPath) | Out-Null
                Get-ChildItem $tempItem | Move-Item -Destination $localPath -Force
            }
            else {
                # item to copy is a file
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($localPath)) | Out-Null
                Move-Item -Path $tempItem -Destination $localPath -Force
            }
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

Export-ModuleMember Copy-ItemFromBcContainer