Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
}

Describe 'SymbolHandling' {

    It 'Generate-SymbolsInNavContainer' {
        #TODO
    }

}
