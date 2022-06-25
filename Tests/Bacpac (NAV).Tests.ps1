Param(
    [string] $licenseFile,
    [string] $buildlicenseFile,
    [string] $insiderSasToken
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveNavContainer.ps1')
}

Describe 'Bacpac' {

    It 'Backup-NavContainerDatabases' {

        $bakFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder ([GUID]::NewGuid().ToString())
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

        . (Join-Path $PSScriptRoot '_RemoveNavContainer.ps1')

        Remove-Item -Path $bakFolder -Recurse -Force
    }
}
