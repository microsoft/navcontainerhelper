Param(
    [string] $licenseFile,
    [string] $buildlicenseFile,
    [string] $insiderSasToken
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
    $appPublisher = "Cronus Denmark A/S"
    $appName = "Hello ÆØÅ"
    $appVersion = "1.0.0.0"
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveNavContainer.ps1')
}

Describe 'AppHandling' {

    It 'Add-GitToAlProjectFolder' {
        #TODO
    }

    It 'Compile-AppInNavContainer' {
        Copy-Item -Path (Join-Path $PSScriptRoot "nav-app") -Destination $navContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $navContainerPath "nav-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $navAppFile = Compile-AppInNavContainer -containerName $navContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols -credential $credential
        $navAppFile | Should -Exist
    }
    It 'Extract-AppFileToFolder (nav app)' {
        $navAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $navAppFile = Join-Path $navContainerPath "nav-app\output\$navAppFileName"
        Extract-AppFileToFolder $navAppFile -appFolder (Join-Path $navContainerPath "nav-app2")
        (Get-ChildItem -Path (Join-Path $navContainerPath "nav-app2\*.al") -Recurse).Count | Should -Be (Get-ChildItem -Path (Join-Path $navContainerPath "nav-app\*.al") -Recurse).Count
    }
    It 'Publish-NavContainerApp' {
        $navAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $navAppFile = Join-Path $navContainerPath "nav-app\output\$navAppFileName"
        Publish-NavContainerApp -containerName $navContainerName -appFile $navAppFile -skipVerification
    }
    It 'Sync-NavContainerApp' {
        Sync-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'Install-NavContainerApp' {
        Install-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'Get-NavContainerApp' {
        Get-NavContainerApp -containerName $navContainerName -publisher $appPublisher -appName $appName -appVersion $appVersion -credential $credential
    }
    It 'Get-NavContainerAppInfo' {
        $myapp = Get-NavContainerAppInfo -containerName $navContainerName | Where-Object { $_.Name -eq $appName }
        $myapp | Should -not -BeNullOrEmpty
    }
    It 'Get-NavContainerAppRuntimePackage' {
        #TODO
    }
    It 'Get-TestsFromNavContainer' {
        $tests = Get-TestsFromNavContainer -containerName $navContainerName -credential $credential
        $tests.Tests | Should -Contain 'WorkingTest'
    }
    It 'Install-NAVSipCryptoProviderFromNavContainer' {
        #TODO
    }
    It 'Repair-NavContainerApp' {
        Repair-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'Run-TestsInNavContainer' {
        $testResultsFile = Join-Path $navContainerPath "TestResults.xml"
        Run-TestsInNavContainer -containerName $navContainerName -credential $credential -detailed -XUnitResultFileName $testResultsFile
        [xml]$testResults = Get-Content $testResultsFile
        $testResults.assemblies.assembly.passed | Should -Be $testResults.assemblies.assembly.total
    }
    It 'Start-NavContainerAppDataUpgrade' {
        #TODO
    }
    It 'UnInstall-NavContainerApp' {
        UnInstall-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'UnPublish-NavContainerApp' {
        UnPublish-NavContainerApp -containerName $navContainerName -appName $appName
    }

    It 'Get/RunTests for all versions' {
        9,10,11,14 | % {

            $runTestsInVersion  = $_
            $artifactUrl = Get-BCArtifactUrl -type OnPrem -version "$runTestsInVersion" -country "w1" -select Latest
            $containerParams = @{ }
            if ($runTestsInVersion -lt 13) {
                $containerParams = @{ 
                    "includeCSIDE" = $true
                    "doNotExportObjectsToText" = $true
                }
            }

            New-NavContainer @containerParams -accept_eula `
                             -accept_outdated `
                             -containerName $navContainerName `
                             -artifactUrl $artifactUrl `
                             -auth NavUserPassword `
                             -Credential $credential `
                             -updateHosts `
                             -licenseFile $licenseFile `
                             -includeTestToolkit

            if ($runTestsInVersion -lt 12) {
                Import-ObjectsToNavContainer -containerName $navContainerName -objectsFile (Join-Path $PSScriptRoot "inserttests.txt") -sqlCredential $credential
                Compile-ObjectsInNavContainer -containerName $navContainerName
                Invoke-NavContainerCodeunit -containerName $navContainerName -Codeunitid 50000 -CompanyName "CRONUS International Ltd."
            }
            else {
                Copy-Item -Path (Join-Path $PSScriptRoot "inserttests") -Destination (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$navContainerName") -Recurse -Force
                $appProjectFolder = Join-Path (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$navContainerName") "inserttests"
                Compile-AppInNavContainer -containerName $navContainerName -credential $credential -appProjectFolder $appProjectFolder -appOutputFolder $appProjectFolder -appName "inserttests.app" -UpdateSymbols
                Publish-NavContainerApp -containerName $navContainerName -appFile (Join-Path $appProjectFolder "inserttests.app") -skipVerification -sync -install
            }

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
        Remove-NavContainer $navContainerName
    }
}