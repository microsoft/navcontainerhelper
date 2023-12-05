Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
}

Describe 'ConfigPackageHandling' {

    It 'Import-ConfigPackageInNavContainer' {
        #TODO
    }
    It 'Remove-ConfigPackageInNavContainer' {
        #TODO
    }

}
