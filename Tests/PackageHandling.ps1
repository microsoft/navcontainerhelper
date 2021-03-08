Describe 'PackageHandling' {
    It 'Get-AzureFeedWildcardVersion' {
        (Get-AzureFeedWildcardVersion -appVersion "1.0.0") | Should Be "1.*.*"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.0") | Should Not Be "1.0.*"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.319") | Should Be "1.0.319"
        (Get-AzureFeedWildcardVersion -appVersion "1.0.319") | Should Not Be "1.*.319"
    }
}