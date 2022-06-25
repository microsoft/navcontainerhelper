Param(
    [string] $licenseFile,
    [string] $buildlicenseFile,
    [string] $insiderSasToken
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
}

Describe 'Bacpac' {

    It 'Backup-BcContainerDatabases' {

        $bakFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "mybak"
        $bakFile = "$bakFolder\database.bak"
        Backup-NavContainerDatabases -containerName $bcContainerName `
                                     -sqlCredential $credential `
                                     -bakFolder $bakFolder

        $bakFile | Should -Exist
                
        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -artifactUrl $bcArtifactUrl `
                         -containerName $bcContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -bakFile $bakFile

        Remove-Item -Path $bakFolder -Recurse -Force

        . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')
    }
    It 'Export-NavContainerDatabasesAsBacpac' {

        $bacpacFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "bacpac"
        $bacpacFile = "$bacpacFolder\database.bacpac"
        Export-NavContainerDatabasesAsBacpac -containerName $bcContainerName -sqlCredential $credential -bacpacFolder $bacpacFolder -doNotCheckEntitlements

        $bacpacFile | Should -Exist

        Remove-Item -Path $bacpacFolder -Recurse -Force
    }
    It 'Export-NavContainerDatabasesAsBacpac (multitenant)' {

        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -artifactUrl $bcArtifactUrl `
                         -containerName $bcContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -multitenant

        $bacpacFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "bacpac"
        $appBacpacFile = "$bacpacFolder\app.bacpac"
        $tenant = "default"
        $tenantBacpacFile = "$bacpacFolder\$tenant.bacpac"
        Export-NavContainerDatabasesAsBacpac -containerName $bcContainerName -sqlCredential $credential -bacpacFolder $bacpacFolder -tenant $tenant -doNotCheckEntitlements

        $appBacpacFile | Should -Exist
        $tenantBacpacFile | Should -Exist

        $containerAppBacpacFile = Join-Path $bcContainerHelperConfig.containerHelperFolder "bacpac\app.bacpac"
        $containerTenantBacpacFile = Join-Path $bcContainerHelperConfig.containerHelperFolder "bacpac\default.bacpac"

        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -imageName $bcImageName `
                         -containerName $bcContainerName `
                         -auth "NavUserPassword" `
                         -Credential $Credential `
                         -updateHosts `
                         -additionalParameters @("--env appBacpac=$containerAppBacpacFile","--env tenantBacpac=$containerTenantBacpacFile")

        New-NavContainerTenant -containerName $bcContainerName -tenantId "test"

        (Get-NavContainerTenants -containerName $bcContainerName).Count | Should -be 2

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
