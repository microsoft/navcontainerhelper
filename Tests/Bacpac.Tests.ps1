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

        $bakFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder ([GUID]::NewGuid().ToString())
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
                         -Credential $credential `
                         -updateHosts `
                         -bakFile $bakFile

        . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')

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
}
