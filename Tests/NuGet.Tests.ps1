Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
    
}

Describe 'Download' {
    It 'Download-BcNuGetPackageToFolder' {
        # Make a test downloading earliest matching as this won't change when new versions are released
        $bcContainerHelperConfig.TrustedNuGetFeeds = @(
        @{ "url" = "https://pkgs.dev.azure.com/continia-repository/ContiniaBCPublicFeeds/_packaging/AppSourceApps/nuget/v3/index.json" }
        )

        $folder = Join-Path ([System.IO.Path]::GetTempPath()) 'nuget'
        Download-BcNuGetPackageToFolder -packageName "6da8dd2f-e698-461f-9147-8e404244dd85" -version "26.0.0.0" -select EarliestMatching -installedApps @(@{"id"="";"name"="Application";"version"="26.5.38752.40172";"publisher"="Microsoft"}) -folder $folder

        $files = @(Get-ChildItem $folder)
        $files.Count | Should -Be 6
    }
}
