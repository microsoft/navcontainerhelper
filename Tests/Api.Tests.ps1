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

Describe 'Api' {
    It 'Get-NavContainerApiCompanyId' {
        #TODO
    }
    It 'Invoke-NavContainerApi' {
        #TODO
    }
}
