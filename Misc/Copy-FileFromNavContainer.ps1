<# 
 .Synopsis
  Copy File from a container
 .Description
  Copies a file from a Container
 .Parameter containerName
  Name of the container from which you want to copy a file
 .Parameter containerPath
  Path of the file in the Container, which has to be copied
 .Parameter localPath
  Path to the file on the host. This cannot be a foldername, it needs to be a filename.
 .Example
  Copy-FileFromBcContainer -containerName test2 -containerPath "c:\run\my\myfile.txt" -localPath "c:\temp\myfile.txt"
#>
function Copy-FileFromBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $containerPath,
        [Parameter(Mandatory=$false)]
        [string] $localPath = $containerPath
    )

    Process {
        if (!(Test-BcContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy from container $containerName ($containerPath) to $localPath"
        $id = Get-BcContainerId -containerName $containerName 

        # running hyperv containers doesn't support docker cp
        $tempFile = Join-Path $hostHelperFolder ([GUID]::NewGuid().ToString())
        try {
            if (Test-Path $localPath -PathType Container) {
                throw "localPath ($localPath) already exists as a folder. Cannot copy file, LocalPath needs to specify a filename."
            }
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($containerPath, $tempFile)
                Copy-Item -Path $containerPath -Destination $tempFile
            } -argumentList $containerPath, (Get-BcContainerPath -containerName $containerName -Path $tempFile)
            Move-Item -Path $tempFile -Destination $localPath -Force
        } finally {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -ErrorAction Ignore
            }
        }
    }
}
Set-Alias -Name Copy-FileFromNavContainer -Value Copy-FileFromBcContainer
Export-ModuleMember -Function Copy-FileFromBcContainer -Alias Copy-FileFromNavContainer
