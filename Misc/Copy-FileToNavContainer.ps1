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

        $session = New-PSSession -ContainerId $id -RunAsAdministrator -ErrorAction Ignore
        if ($session) {
            Copy-Item -Path $localPath -Destination $containerPath -ToSession $session
            Remove-PSSession -Session $session
        } else {
            docker cp $localPath ${id}:$containerPath
        }
    }
}
Export-ModuleMember Copy-FileToNavContainer
