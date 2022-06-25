Describe 'Bacpac' {

    It 'Backup-NavContainerDatabases' {

        $bakFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "mybak"
        $bakFile = "$bakFolder\database.bak"
        Backup-NavContainerDatabases -containerName $navContainerName `
                                     -sqlCredential $credential `
                                     -bakFolder $bakFolder

        $bakFile | Should -Exist
                
        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -artifactUrl $navArtifactUrl `
                         -containerName $navContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -bakFile $bakFile

        Remove-Item -Path $bakFolder -Recurse -Force
    }
}
