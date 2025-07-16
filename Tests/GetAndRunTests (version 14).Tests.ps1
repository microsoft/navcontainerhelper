Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    $appPublisher = "Cronus Denmark A/S"
    $appName = "Hello ÆØÅ"
    $appVersion = "1.0.0.0"
    $runTestsInVersion  = 14
    $navContainerName = "navserver"
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveNavContainer.ps1')
}

Describe 'AppHandling' {

    It 'Get/RunTests' {
        $artifactUrl = Get-BCArtifactUrl -type OnPrem -version "$runTestsInVersion" -country "w1" -select Latest
        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -containerName $navContainerName `
                         -artifactUrl $artifactUrl `
                         -auth NavUserPassword `
                         -Credential $credential `
                         -updateHosts `
                         -licenseFile $licenseFile `
                         -includeTestToolkit

        Copy-Item -Path (Join-Path $PSScriptRoot "inserttests") -Destination (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$navContainerName") -Recurse -Force
        $appProjectFolder = Join-Path (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$navContainerName") "inserttests"
        Compile-AppInNavContainer -containerName $navContainerName -credential $credential -appProjectFolder $appProjectFolder -appOutputFolder $appProjectFolder -appName "inserttests.app" -UpdateSymbols
        Publish-NavContainerApp -containerName $navContainerName -appFile (Join-Path $appProjectFolder "inserttests.app") -skipVerification -sync -install

        $tests = (Get-TestsFromNavContainer -containerName $navContainerName -credential $credential).Codeunits
        $tests.Count | Should -be 2
    
        $first = $true
        $resultsFile = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$navContainerName\result.xml"
        $tests | % {
            $allpassed = Run-TestsInNavContainer -containerName $navContainerName `
                                                 -credential $credential `
                                                 -XUnitResultFileName $resultsFile `
                                                 -AppendToXUnitResultFile:(!$first) `
                                                 -detailed `
                                                 -testCodeunit $_.Id `
                                                 -returnTrueIfAllPassed
            $first = $false
        }
        $resultsFile | Should -Exist
    }
}