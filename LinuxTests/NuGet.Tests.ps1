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

Describe 'Find-BcNuGetPackage' {
    BeforeEach {
        # Configure the app source feed and continia feed for different package ids to test sorting accross multiple packages and feeds
        # Configure the continia feed twice for the same package id to test deduplication across multiple feeds
        $bcContainerHelperConfig.TrustedNuGetFeeds = @(
            @{ "url" = "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json" },
            @{ "url" = "https://pkgs.dev.azure.com/continia-repository/ContiniaBCPublicFeeds/_packaging/AppSourceApps/nuget/v3/index.json" },
            @{ "url" = "https://pkgs.dev.azure.com/continia-repository/ContiniaBCPublicFeeds/_packaging/AppSourceApps/nuget/v3/index.json" }
        )
    }

    It 'Find-BcNuGetPackage returns deduplicated results in ascending order across multiple feeds' {
        # Capture Information stream (Write-Host) alongside the result to verify both feeds were searched
        $allOutput = @(Find-BcNuGetPackage -packageName "6da8dd2f-e698-461f-9147-8e404244dd85" -version '0.0.0.0' -select AllAscending -allowPrerelease 6>&1)
        $result = @($allOutput | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $infoOutput = ($allOutput | Where-Object { $_ -is [System.Management.Automation.InformationRecord] }) -join "`n"

        # Verify both feeds were actually searched (matchingPackagesCount = 2 triggers deduplication)
        $infoOutput | Should -BeLike '*Found 3 matching packages across all feeds*'

        # Should have found more than one version
        $result.Count | Should -BeGreaterThan 1

        # No duplicate PackageId+PackageVersion entries after deduplication
        $uniqueKeys = @($result | ForEach-Object { "$($_.PackageId)|$($_.PackageVersion)" } | Select-Object -Unique)
        $uniqueKeys.Count | Should -Be $result.Count

        # Both unique feeds should be represented in the results once
        $uniqueFeeds = @($result | ForEach-Object { "$($_.Feed.Url)" } | Select-Object -Unique)
        $uniqueFeeds.Count | Should -Be 2

        # Versions should be in ascending order
        for ($i = 0; $i -lt $result.Count - 1; $i++) {
            $v1 = ($result[$i].PackageVersion -replace '-.+$') -as [System.Version]
            $v2 = ($result[$i + 1].PackageVersion -replace '-.+$') -as [System.Version]
            $v1 | Should -BeLessOrEqual $v2
        }
    }

    It 'Find-BcNuGetPackage returns deduplicated results in descending order across multiple feeds' {
        # Capture Information stream (Write-Host) alongside the result to verify both feeds were searched
        $allOutput = @(Find-BcNuGetPackage -packageName "6da8dd2f-e698-461f-9147-8e404244dd85" -version '0.0.0.0' -select AllDescending -allowPrerelease 6>&1)
        $result = @($allOutput | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $infoOutput = ($allOutput | Where-Object { $_ -is [System.Management.Automation.InformationRecord] }) -join "`n"

        # Verify both feeds were actually searched (matchingPackagesCount = 2 triggers deduplication)
        $infoOutput | Should -BeLike '*Found 3 matching packages across all feeds*'

        # Should have found more than one version
        $result.Count | Should -BeGreaterThan 1

        # No duplicate PackageId+PackageVersion entries after deduplication
        $uniqueKeys = @($result | ForEach-Object { "$($_.PackageId)|$($_.PackageVersion)" } | Select-Object -Unique)
        $uniqueKeys.Count | Should -Be $result.Count

        # Both unique feeds should be represented in the results once
        $uniqueFeeds = @($result | ForEach-Object { "$($_.Feed.Url)" } | Select-Object -Unique)
        $uniqueFeeds.Count | Should -Be 2

        # Versions should be in descending order
        for ($i = 0; $i -lt $result.Count - 1; $i++) {
            $v1 = ($result[$i].PackageVersion -replace '-.+$') -as [System.Version]
            $v2 = ($result[$i + 1].PackageVersion -replace '-.+$') -as [System.Version]
            $v1 | Should -BeGreaterOrEqual $v2
        }
    }
}
