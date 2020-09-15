<# 
 .Synopsis
  Copy File to a container
 .Description
  Copies a file to a Container
 .Parameter containerName
  Name of the container to which you want to copy a file
 .Parameter localPath
  Path to the file on the host, which has to be copied
 .Parameter containerPath
  Path of the file in the Container. This cannot be a foldername, it needs to be a filename.
 .Example
  Copy-FileToBcContainer -containerName test2 -localPath "c:\temp\myfile.txt" -containerPath "c:\run\my\myfile.txt"
#>
function Copy-FileToBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $localPath,
        [Parameter(Mandatory=$false)]
        [string] $containerPath = $localPath
    )

    Process {
        if (!(Test-BcContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy $localPath to container ${containerName} ($containerPath)"
        $id = Get-BcContainerId -containerName $containerName 

        # running hyperv containers doesn't support docker cp
        $tempFile = Join-Path $hostHelperFolder ([GUID]::NewGuid().ToString())
        try {
            Copy-Item -Path $localPath -Destination $tempFile
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($tempFile, $containerPath)
                if (Test-Path $containerPath -PathType Container) {
                    throw "ContainerPath ($containerPath) already exists as a folder. Cannot copy file, ContainerPath needs to specify a filename."
                }
                $directory = [System.IO.Path]::GetDirectoryName($containerPath)
                if (-not (Test-Path $directory -PathType Container)) {
                    New-Item -Path $directory -ItemType Directory | Out-Null
                }
                Move-Item -Path $tempFile -Destination $containerPath -Force
            } -argumentList (Get-BcContainerPath -containerName $containerName -Path $tempFile), $containerPath
        } finally {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -ErrorAction Ignore
            }
        }
    }
}
Set-Alias -Name Copy-FileToNavContainer -Value Copy-FileToBcContainer
Export-ModuleMember -Function Copy-FileToBcContainer -Alias Copy-FileToNavContainer
