Param(
    [string] $licenseFile,
    [string] $buildlicenseFile,
    [string] $insiderSasToken
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
}

Describe 'CompanyHandling' {

    It 'Copy-CompanyInNavContainer' {
        #TODO
    }
    It 'Get-CompanyInNavContainer' {
        #TODO
    }
    It 'New-CompanyInNavContainer' {
        #TODO
    }
    It 'Remove-CompanyInNavContainer' {
        #TODO
    }

}
