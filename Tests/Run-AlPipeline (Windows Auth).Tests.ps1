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
            -previousApps @("https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/19.0.0/bcsamples-bingmaps.pte-main-Apps-19.0.168.0.zip") `
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
