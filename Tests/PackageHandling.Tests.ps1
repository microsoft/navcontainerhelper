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
        (Get-AzureFeedWildcardVersion -appVersion "1.0.0") | Should Be "1.*.*"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.0") | Should Not Be "1.0.*"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.319") | Should Be "1.0.319"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.319") | Should Not Be "1.*.319"
    }
    It 'Resolve-DependenciesFromAzureFeed' {
        Resolve-DependenciesFromAzureFeed -organization "https://dev.azure.com/TEST/" -feed "BCApps" -appsFolder (Join-Path $PSScriptRoot ".\helloworld")
    }
}