Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    $appPublisher = "Cronus Denmark A/S"
    $appName = "Hello ÆØÅ"
    $appVersion = "1.0.0.0"
    $runTestsInVersion  = 9
    $navContainerName = "navserver"
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveNavContainer.ps1')
}

Describe 'AppHandling' -Skip {

    It 'Get/RunTests' {
        $artifactUrl = Get-BCArtifactUrl -type OnPrem -version "$runTestsInVersion" -country "w1" -select Latest
        New-NavContainer -accept_eula `
                         -accept_outdated `
                         -includeCSide `
                         -doNotExportObjectsToText `
                         -containerName $navContainerName `
                         -artifactUrl $artifactUrl `
                         -auth NavUserPassword `
                         -Credential $credential `
                         -updateHosts `
                         -licenseFile $licenseFile `
                         -includeTestToolkit

        Import-ObjectsToNavContainer -containerName $navContainerName -objectsFile (Join-Path $PSScriptRoot "inserttests.txt") -sqlCredential $credential
        Compile-ObjectsInNavContainer -containerName $navContainerName
        Invoke-NavContainerCodeunit -containerName $navContainerName -Codeunitid 50000 -CompanyName "CRONUS International Ltd."

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
