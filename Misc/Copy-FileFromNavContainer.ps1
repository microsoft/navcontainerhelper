function Copy-FileFromNavContainer {

    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$containerPath,
        [Parameter(Mandatory=$false)]
        [string]$localPath = $containerPath
    )

    Process {
        if (!(Test-NavContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy from container $containerName ($containerPath) to $localPath"
        $id = Get-NavContainerId -containerName $containerName 

        $inspect = docker inspect $containerName | ConvertFrom-Json
        if (!$inspect.State.Running -or $inspect.hostConfig.Isolation -eq "process") {
            docker cp ${id}:$containerPath $localPath
        } else {
            # running hyperv containers doesn't support docker cp
            $tempFile = Join-Path $containerHelperFolder ([GUID]::NewGuid().ToString())
            try {
                Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param($containerPath, $tempFile)
                    Copy-Item -Path $containerPath -Destination $tempFile
                } -argumentList $containerPath, $tempFile
                Move-Item -Path $tempFile -Destination $localPath -Force
            } finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -ErrorAction Ignore
                }
            }
        }
    }
}
Export-ModuleMember Copy-FileFromNavContainer
