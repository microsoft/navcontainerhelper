Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
}

Describe 'AzureVM' {

    It 'New-LetsEncryptCertificate' {
        #TODO
    }
    It 'Renew-LetsEncryptCertificate' {
        #TODO
    }
    It 'Replace-NavServerContainer' {
        #TODO
    }

}
