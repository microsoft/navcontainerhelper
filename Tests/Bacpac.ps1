Describe 'Bacpac' {

    It 'Backup-NavContainerDatabases' {

        $bakFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "mybak"
        $bakFile = "$bakFolder\database.bak"
        Backup-NavContainerDatabases -containerName $navContainerName `
                                     -sqlCredential $credential `
                                     -bakFolder $bakFolder

        $bakFile | Should -Exist
                
        $testContainerName = "$($navContainerName)2"
        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -artifactUrl $navArtifactUrl `
                         -containerName $testContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -bakFile $bakFile

        Remove-NavContainer $testContainerName
        Remove-Item -Path $bakFolder -Recurse -Force
    }
    It 'Export-NavContainerDatabasesAsBacpac' {

        $bacpacFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "bacpac"
        $bacpacFile = "$bacpacFolder\database.bacpac"
        Export-NavContainerDatabasesAsBacpac -containerName $bcContainerName -sqlCredential $credential -bacpacFolder $bacpacFolder -doNotCheckEntitlements

        $bacpacFile | Should -Exist

        Remove-Item -Path $bacpacFolder -Recurse -Force
    }
    It 'Export-NavContainerDatabasesAsBacpac (multitenant)' {

        $testContainerName = "$($bcContainerName)2"
        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -artifactUrl $bcArtifactUrl `
                         -containerName $testContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -multitenant

        $bacpacFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "bacpac"
        $appBacpacFile = "$bacpacFolder\app.bacpac"
        $tenant = "default"
        $tenantBacpacFile = "$bacpacFolder\$tenant.bacpac"
        Export-NavContainerDatabasesAsBacpac -containerName $testContainerName -sqlCredential $credential -bacpacFolder $bacpacFolder -tenant $tenant -doNotCheckEntitlements

        $appBacpacFile | Should -Exist
        $tenantBacpacFile | Should -Exist

        $containerAppBacpacFile = Join-Path $bcContainerHelperConfig.containerHelperFolder "bacpac\app.bacpac"
        $containerTenantBacpacFile = Join-Path $bcContainerHelperConfig.containerHelperFolder "bacpac\default.bacpac"

        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -imageName $bcImageName `
                         -containerName $testContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -additionalParameters @("--env appBacpac=$containerAppBacpacFile","--env tenantBacpac=$containerTenantBacpacFile")

        New-NavContainerTenant -containerName $testContainerName -tenantId "test"

        (Get-NavContainerTenants -containerName $testContainerName).Count | Should -be 2

        Remove-NavContainer $testContainerName
        Remove-Item -Path $bacpacFolder -Recurse -Force
    }
    It 'Remove-BcDatabase' {
        #TODO
    }
    It 'Restore-BcDatabaseFromArtifacts' {
        #TODO
    }
    It 'Restore-DatabasesInNavContainer' {
        #TODO
    }
}
