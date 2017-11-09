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
        docker cp ${id}:$containerPath $localPath
    }
}
Export-ModuleMember Copy-FileFromNavContainer
