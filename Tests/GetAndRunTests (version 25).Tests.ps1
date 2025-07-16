Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    $appPublisher = "Cronus Denmark A/S"
    $appName = "Hello ÆØÅ"
    $appVersion = "1.0.0.0"
    $bcAppId = "cb99d78b-f9db-4a1e-822a-0c9c444535df"
    $runTestsInVersion  = 25
    $bcContainerName = "bcserver"
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
}

Describe 'AppHandling' {

    It 'Get/RunTests' {
        $artifactUrl = Get-BCArtifactUrl -type OnPrem -version "$runTestsInVersion" -country "w1" -select Latest
        New-BcContainer -accept_eula `
                        -accept_outdated `
                        -containerName $bcContainerName `
                        -artifactUrl $artifactUrl `
                        -auth NavUserPassword `
                        -Credential $credential `
                        -updateHosts `
                        -includeTestToolkit
        
        $tests = (Get-TestsFromBCContainer -containerName $bcContainerName -credential $credential -extensionId "fa3e2564-a39e-417f-9be6-c0dbe3d94069") | Where-Object { $_.id -eq 134006 -or $_.id -eq 134007 }
        $tests.Count | Should -be 2

        $first = $true
        $resultsFile = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$bcContainerName\result.xml"
        $tests | ForEach-Object {
            Run-TestsInBcContainer -containerName $bcContainerName `
                                   -credential $credential `
                                   -XUnitResultFileName $resultsFile `
                                   -AppendToXUnitResultFile:(!$first) `
                                   -detailed `
                                   -testCodeunit $_.Id `
                                   -returnTrueIfAllPassed | Out-Null
            $first = $false
        }
        $resultsFile | Should -Exist
    }
}