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

Describe 'PackageHandling' {
    It 'Get-AzureFeedWildcardVersion' {
        (Get-AzureFeedWildcardVersion -appVersion "1.0.0") | Should -be "1.*.*"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.0") | Should -not -be "1.0.*"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.319") | Should -be "1.0.319"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.319") | Should -not -be "1.*.319"
    }
    It 'Resolve-DependenciesFromAzureFeed' {
        Resolve-DependenciesFromAzureFeed -organization "https://dev.azure.com/TEST/" -feed "BCApps" -appsFolder (Join-Path $PSScriptRoot ".\helloworld")
    }
}