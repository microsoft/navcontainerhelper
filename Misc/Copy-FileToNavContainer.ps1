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
        docker cp $localPath ${id}:$containerPath
    }
}
Export-ModuleMember Copy-FileToNavContainer
