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
            -licenseFile $buildlicenseFile `
            -containerName nchbuild `
            -credential $credential `
            -installApps @("https://businesscentralapps.azureedge.net/hidestuff/latest/apps.zip") `
            -appFolders "app,base" `
            -testFolders @("test") `
            -previousApps @("https://businesscentralapps.blob.core.windows.net/githubhelloworld/2.0.32.0/apps.zip") `
            -additionalCountries "dk,de" `
            -appBuild ([int32]::MaxValue) `
            -appRevision 0 `
            -testResultsFile $resultsFile `
            -testResultsFormat JUnit `
            -artifact (Get-BCArtifactUrl -country us -select Current) `
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
}
