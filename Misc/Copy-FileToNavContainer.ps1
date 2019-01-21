function Copy-FileToNavContainer {

    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$localPath,
        [Parameter(Mandatory=$false)]
        [string]$containerPath = $localPath
    )

    Process {
        if (!(Test-NavContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy $localPath to container ${containerName} ($containerPath)"
        $id = Get-NavContainerId -containerName $containerName 

        $inspect = docker inspect $containerName | ConvertFrom-Json
        if (!$inspect.State.Running -or $inspect.hostConfig.Isolation -eq "process") {
            docker cp $localPath ${id}:$containerPath
        } else {
            # running hyperv containers doesn't support docker cp
            $tempFile = Join-Path $containerHelperFolder ([GUID]::NewGuid().ToString())
            try {
                Copy-Item -Path $localPath -Destination $tempFile
                Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param($tempFile, $containerPath)
                    Move-Item -Path $tempFile -Destination $containerPath -Force
                } -argumentList $tempFile, $containerPath
            } finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -ErrorAction Ignore
                }
            }
        }
    }
}
Export-ModuleMember Copy-FileToNavContainer
