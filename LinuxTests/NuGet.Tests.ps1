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
        $bcContainerHelperConfig.TrustedNuGetFeeds = @(
        @{ "url" = "https://pkgs.dev.azure.com/continia-repository/ContiniaBCPublicFeeds/_packaging/AppSourceApps/nuget/v3/index.json" }
        )

        Measure-Command {
            $folder = Join-Path ([System.IO.Path]::GetTempPath()) 'nuget'
            Download-BcNuGetPackageToFolder -packageName "6da8dd2f-e698-461f-9147-8e404244dd85" -version "26.0.0.0" -select LatestMatching -installedApps @(@{"id"="";"name"="Application";"version"="26.5.38752.40172";"publisher"="Microsoft"}) -folder $folder
        }

        $files = @(Get-ChildItem $folder)
        $files.Count | Should -BeGreaterThan 5
    }
}
