Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    $bccontainerName = "bcserver"
}

AfterAll {
}

Describe 'Run-AlPipeline' {
    It 'Run-AlPipeline' {
        $baseFolder = Join-Path $PSScriptRoot "helloworld"
        $resultsFile = Join-Path $baseFolder "result.xml"
        $buildArtifactFolder = Join-Path $baseFolder "buildArtifactFolder"
        $outputFolder = Join-Path $baseFolder "output"
        Remove-Item $resultsFile -Force -ErrorAction SilentlyContinue
        Remove-Item $buildArtifactFolder -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outputFolder -Recurse -Force -ErrorAction SilentlyContinue

        Run-AlPipeline `
            -pipelineName nch `
            -baseFolder $baseFolder `
            -containerName $bccontainerName `
            -credential $credential `
            -installApps @("https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/24.0.0/bcsamples-bingmaps.pte-main-Apps-24.0.169.0.zip") `
            -appFolders "app,base" `
            -testFolders @("test") `
            -previousApps @((Join-Path $PSScriptRoot 'helloworld-previousapps.zip')) `
            -additionalCountries "dk,de" `
            -appBuild ([int32]::MaxValue) `
            -appRevision 0 `
            -testResultsFile $resultsFile `
            -testResultsFormat JUnit `
            -artifact "///us/Current" `
            -imageName '' `
            -outputFolder $outputFolder `
            -buildArtifactFolder $buildArtifactFolder `
            -createRuntimePackages `
            -installTestFramework `
            -gitHubActions `
            -enablePerTenantExtensionCop

        Remove-Item $resultsFile -Force -ErrorAction SilentlyContinue
        Remove-Item $buildArtifactFolder -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outputFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'forwards installed app context and publishes missing test dependencies before test apps when using compiler folder' {
        $baseFolder = Join-Path $PSScriptRoot "helloworld"
        $previousAppsFile = Join-Path $PSScriptRoot "helloworld-previousapps.zip"
        $resultsFile = Join-Path $baseFolder "result.xml"
        $buildArtifactFolder = Join-Path $baseFolder "buildArtifactFolder"
        $outputFolder = Join-Path $baseFolder "output"
        $packagesFolder = Join-Path $baseFolder "packages"
        Remove-Item $resultsFile -Force -ErrorAction SilentlyContinue
        Remove-Item $buildArtifactFolder -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outputFolder -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $packagesFolder -Recurse -Force -ErrorAction SilentlyContinue

        try {
            $script:installMissingDependenciesParameters = $null
            $script:publishedAppFiles = @()

            Run-AlPipeline `
                -pipelineName nch `
                -baseFolder $baseFolder `
                -containerName $bccontainerName `
                -credential $credential `
                -appFolders @() `
                -testFolders @("test") `
                -appBuild ([int32]::MaxValue) `
                -appRevision 0 `
                -testResultsFile $resultsFile `
                -testResultsFormat JUnit `
                -artifact "///us/Current" `
                -imageName '' `
                -outputFolder $outputFolder `
                -buildArtifactFolder $buildArtifactFolder `
                -useCompilerFolder `
                -packagesFolder $packagesFolder `
                -environment "https://localhost" `
                -bcAuthContext @{ username = "dummy"; password =  ConvertTo-SecureString "dummy" -AsPlainText } `
                -doNotRunTests `
                -installTestRunner `
                -installTestFramework `
                -installTestLibraries `
                -installPerformanceToolkit `
                -InstallMissingDependencies {
                    Param(
                        [Hashtable] $parameters
                    )
                    $script:installMissingDependenciesParameters = $parameters
                    $tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
                    try {
                        Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
                        Expand-Archive -Path $previousAppsFile -DestinationPath $tempFolder -Force
                        Get-ChildItem -Path $tempFolder -Filter '*.app' -Recurse | ForEach-Object {
                            Move-Item -Path $_.FullName -Destination $parameters.appSymbolsFolder -Force
                        }
                    }
                    finally {
                        Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
                    }
                } `
                -ImportTestToolkitToBcContainer {
                    Param(
                        [Hashtable] $parameters
                    )
                } `
                -PublishBcContainerApp {
                    Param(
                        [Hashtable] $parameters
                    )
                    $script:publishedAppFiles += $parameters.appFile
                }

            $script:installMissingDependenciesParameters.installedApps | Should -Not -BeNullOrEmpty
            $script:installMissingDependenciesParameters.installedCountry | Should -Be "us"
            $script:installMissingDependenciesParameters.missingDependencies | Should -Contain '00000000-0000-0000-0000-000000000001:Default Publisher_Default App Name_2.0.0.0.app'

            $script:publishedAppFiles | Should -Not -BeNullOrEmpty
            $dependencyIndex = [array]::FindIndex([string[]]$script:publishedAppFiles, [Predicate[string]] { param($appFile) $appFile -like '*Default Publisher_Default App Name_2.0.*.app' })
            $testAppIndex = [array]::FindIndex([string[]]$script:publishedAppFiles, [Predicate[string]] { param($appFile) $appFile -like '*Default Publisher_Default Test App Name_2.0.*.app' })

            $dependencyIndex | Should -BeGreaterThan -1
            $testAppIndex | Should -BeGreaterThan -1
            $dependencyIndex | Should -BeLessThan $testAppIndex
        }
        finally {
            Remove-Item $resultsFile -Force -ErrorAction SilentlyContinue
            Remove-Item $buildArtifactFolder -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $outputFolder -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $packagesFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
