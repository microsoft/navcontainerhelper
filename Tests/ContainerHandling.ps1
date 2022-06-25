Describe 'ContainerHandling' {

    It 'Enter-BcContainer' {
        #TODO
    }
    It 'Extract-FilesFromBcContainerImage' {
        #TODO
    }
    It 'Extract-FilesFromStoppedBcContainer' {
        #TODO
    }
    It 'Get-BestBcContainerImageName' {
        #TODO
    }
    It 'Get-BcContainerSession' {
        #TODO
    }
    It 'Import-BcContainerLicense' {
        #TODO
    }
    It 'Invoke-ScriptInBcContainer' {
        #TODO
    }
    It 'New-BcContainer' {
        #TODO
    }
    It 'Open-BcContainer' {
        #TODO
    }
    It 'Remove-BcContainer' {
        #TODO
    }
    It 'Remove-BcContainerSession' {
        #TODO
    }
    It 'Restart-BcContainer' {
        Restart-BcContainer -containerName $bcContainerName
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        $json.State.Status | Should -Be 'running'
    }
    It 'Setup-TraefikContainerForBcContainers' {
        #TODO
    }
    It 'Stop/Start-BcContainer' {
        Stop-BcContainer -containerName $bcContainerName
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        $json.State.Status | Should -Be 'exited'
        Start-BcContainer -containerName $bcContainerName
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        $json.State.Status | Should -Be 'running'
    }
    It 'Wait-BcContainerReady' {
        #TODO
    }

}
