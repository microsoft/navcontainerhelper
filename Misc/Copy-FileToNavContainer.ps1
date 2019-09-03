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
  Copy-FileToNavContainer -containerName test2 -localPath "c:\temp\myfile.txt" -containerPath "c:\run\my\myfile.txt"
#>
function Copy-FileToNavContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerName,
        [Parameter(Mandatory=$true)]
        [string] $localPath,
        [Parameter(Mandatory=$false)]
        [string] $containerPath = $localPath
    )

    Process {
        if (!(Test-NavContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy $localPath to container ${containerName} ($containerPath)"
        $id = Get-NavContainerId -containerName $containerName 

        # running hyperv containers doesn't support docker cp
        $tempFile = Join-Path $containerHelperFolder ([GUID]::NewGuid().ToString())
        try {
            Copy-Item -Path $localPath -Destination $tempFile
            Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param($tempFile, $containerPath)
                if (Test-Path $containerPath -PathType Container) {
                    throw "ContainerPath ($containerPath) already exists as a folder. Cannot copy file, ContainerPath needs to specify a filename."
                }
                Move-Item -Path $tempFile -Destination $containerPath -Force
            } -argumentList $tempFile, $containerPath
        } finally {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -ErrorAction Ignore
            }
        }
    }
}
Set-Alias -Name Copy-FileToBCContainer -Value Copy-FileToNavContainer
Export-ModuleMember -Function Copy-FileToNavContainer -Alias Copy-FileToBCContainer
