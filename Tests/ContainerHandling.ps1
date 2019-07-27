Describe 'ContainerHandling' {

    It 'Enter-NavContainer' {
        #TODO
    }
    It 'Extract-FilesFromNavContainerImage' {
        #TODO
    }
    It 'Extract-FilesFromStoppedNavContainer' {
        #TODO
    }
    It 'Get-BestNavContainerImageName' {
        #TODO
    }
    It 'Get-NavContainerSession' {
        #TODO
    }
    It 'Import-NavContainerLicense' {
        #TODO
    }
    It 'Invoke-ScriptInNavContainer' {
        #TODO
    }
    It 'New-NavContainer' {
        #TODO
    }
    It 'Open-NavContainer' {
        #TODO
    }
    It 'Remove-NavContainer' {
        #TODO
    }
    It 'Remove-NavContainerSession' {
        #TODO
    }
    It 'Restart-NavContainer' {
        Restart-NavContainer -containerName $bcContainerName
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        $json.State.Status | Should -Be 'running'
    }
    It 'Setup-TraefikContainerForNavContainers' {
        #TODO
    }
    It 'Stop/Start-NavContainer' {
        Stop-NavContainer -containerName $bcContainerName
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        $json.State.Status | Should -Be 'exited'
        Start-NavContainer -containerName $bcContainerName
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        $json.State.Status | Should -Be 'running'
    }
    It 'Wait-NavContainerReady' {
        #TODO
    }

}
