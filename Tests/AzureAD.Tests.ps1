Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
}

Describe 'AzureAD' {

    It 'Create-AadAppsForNav' {
        #TODO
    }
    It 'Create-AadUsersInNavContainer' {
        #TODO
    }

}
