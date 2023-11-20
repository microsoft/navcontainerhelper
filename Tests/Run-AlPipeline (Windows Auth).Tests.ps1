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
            -installApps @("https://businesscentralapps.blob.core.windows.net/bingmaps-pte/latest/bingmaps-pte-apps.zip") `
            -appFolders "app,base" `
            -testFolders @("test") `
            -previousApps @("https://businesscentralapps.blob.core.windows.net/githubhelloworld/2.0.32.0/apps.zip") `
            -appBuild ([int32]::MaxValue) `
            -appRevision 0 `
            -testResultsFile $resultsFile `
            -testResultsFormat JUnit `
            -artifact "///base/Current" `
            -imageName '' `
            -outputFolder $outputFolder `
            -buildArtifactFolder $buildArtifactFolder `
            -createRuntimePackages `
            -installTestFramework `
            -gitHubActions `
            -enablePerTenantExtensionCop `
            -NewBcContainer {
                Param(
                    [Hashtable]$parameters
                )
                $parameters.multitenant = $false
                $parameters.RunSandboxAsOnPrem = $true
                $parameters.myscripts = @( @{ "SetupNavUsers.ps1" = "Write-Host 'Skipping user creation'" } )
                $parameters.auth = 'Windows'
                New-BcContainer @parameters
            }
     

        Remove-Item $resultsFile -Force -ErrorAction SilentlyContinue
        Remove-Item $buildArtifactFolder -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outputFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
