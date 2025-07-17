Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1') -sandbox
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
}

Describe 'Bacpac' -Skip {

    It 'Export-NavContainerDatabasesAsBacpac (multitenant)' {

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
}
