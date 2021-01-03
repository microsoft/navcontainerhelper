Describe 'AppHandling' {

    $appPublisher = "Cronus Denmark A/S"
    $appName = "Hello ÆØÅ"
    $appVersion = "1.0.0.0"
    $bcAppId = "cb99d78b-f9db-4a1e-822a-0c9c444535df"

    It 'Add-GitToAlProjectFolder' {
        #TODO
    }
    It 'Clean-BcContainerDatabase' {
        #TODO
    }

    It 'Compile-AppInNavContainer' {
        Copy-Item -Path (Join-Path $PSScriptRoot "nav-app") -Destination $navContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $navContainerPath "nav-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $authParam = @{}
        if ($auth -ne "Windows") {
            $authParam += @{ "Credential" = $credential }
        }
        $navAppFile = Compile-AppInNavContainer -containerName $navContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols @authParam
        $navAppFile | Should -Exist
    }
    It 'Compile-AppInBcContainer' {
        Copy-Item -Path (Join-Path $PSScriptRoot "bc-app") -Destination $bcContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $bcContainerPath "bc-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $authParam = @{}
        if ($auth -ne "Windows") {
            $authParam += @{ "Credential" = $credential }
        }
        $bcAppFile = Compile-AppInBcContainer -containerName $bcContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols @authParam
        $bcAppFile | Should -Exist

        Publish-BcContainerApp -containerName $bcContainerName -appFile $bcAppFile -skipVerification -sync -install

        Copy-Item -Path (Join-Path $PSScriptRoot "bc2-app") -Destination $bcContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $bcContainerPath "bc2-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $bc2AppFile = Compile-AppInBcContainer -containerName $bcContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols @authParam
        $bc2AppFile | Should -Exist

        UnPublish-BCContainerApp -containerName $bcContainerName -appName $appName -publisher $appPublisher -version $appVersion -unInstall -doNotSaveData
    }
    It 'Convert-ALCOutputToAzureDevOps' {
        #TODO
    }
    It 'Copy-AlSourceFiles' {
        #TODO
    }
    It 'Create-AlProjectFolderFromNavContainer' {
        #TODO
    }
    It 'Extract-AppFileToFolder (nav app)' {
        $navAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $navAppFile = Join-Path $navContainerPath "nav-app\output\$navAppFileName"
        Extract-AppFileToFolder $navAppFile -appFolder (Join-Path $navContainerPath "nav-app2")
        (Get-ChildItem -Path (Join-Path $navContainerPath "nav-app2\*.al") -Recurse).Count | Should -Be (Get-ChildItem -Path (Join-Path $navContainerPath "nav-app\*.al") -Recurse).Count
    }
    It 'Extract-AppFileToFolder (bc app)' {
        $bcAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $bcAppFile = Join-Path $bcContainerPath "bc-app\output\$bcAppFileName"
        Extract-AppFileToFolder $bcAppFile -appFolder (Join-Path $bcContainerPath "bc-app2")
        (Get-ChildItem -Path (Join-Path $bcContainerPath "bc-app\*.al") -Recurse).Count | Should -Be (Get-ChildItem -Path (Join-Path $bcContainerPath "bc-app2\*.al") -Recurse).Count
    }
    It 'Publish-NavContainerApp' {
        $navAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $navAppFile = Join-Path $navContainerPath "nav-app\output\$navAppFileName"
        Publish-NavContainerApp -containerName $navContainerName -appFile $navAppFile -skipVerification
    }
    It 'Sign-BcContainerApp' {
        $bcAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $bcAppFile = Join-Path $bcContainerPath "bc-app\output\$bcAppFileName"
        $certFile = Join-Path $bcContainerPath "myCert.pfx"
        New-SelfSignedCertificate –Type CodeSigningCert –Subject “CN=FreddyK” | Export-PfxCertificate -FilePath $certFile -Password $Credential.Password
        Sign-BcContainerApp -containerName $bcContainerName -appFile $bcAppFile -pfxFile $certFile -pfxPassword $Credential.Password
        Import-PfxCertificateToBcContainer -containerName $bcContainerName -pfxCertificatePath $certFile -pfxPassword $Credential.Password -CertificateStoreLocation "Cert:\LocalMachine\Root"
    }
    It 'Publish-BcContainerApp' {
        $bcAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $bcAppFile = Join-Path $bcContainerPath "bc-app\output\$bcAppFileName"
        Publish-BcContainerApp -containerName $bcContainerName -appFile $bcAppFile
    }
    It 'Sync-NavContainerApp' {
        Sync-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'Sync-BcContainerApp' {
        Sync-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'Install-NavContainerApp' {
        Install-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'Install-BcContainerApp' {
        Install-navContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'Get-NavContainerApp' {
        Get-NavContainerApp -containerName $navContainerName -publisher $appPublisher -appName $appName -appVersion $appVersion -credential $credential
    }
    It 'Get-NavContainerAppInfo' {
        $myapp = Get-NavContainerAppInfo -containerName $navContainerName | Where-Object { $_.Name -eq $appName }
        $myapp | Should -not -BeNullOrEmpty
    }
    It 'Get-BcContainerAppInfo' {
        $myapp = Get-BcContainerAppInfo -containerName $bcContainerName | Where-Object { $_.Name -eq $appName }
        $myapp | Should -not -BeNullOrEmpty
    }
    It 'Get-NavContainerAppRuntimePackage' {
        #TODO
    }
    It 'Get-TestsFromNavContainer' {
        $tests = Get-TestsFromNavContainer -containerName $navContainerName -credential $credential
        $tests.Tests | Should -Contain 'WorkingTest'
    }
    It 'Get-TestsFromBcContainer' {
        $tests = Get-TestsFromBcContainer -containerName $bcContainerName -credential $credential -extensionId $bcAppId
        $tests.Tests | Should -Contain 'WorkingTest'
    }
    It 'Install-NAVSipCryptoProviderFromNavContainer' {
        #TODO
    }
    It 'Repair-NavContainerApp' {
        Repair-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'Repair-BcContainerApp' {
        Repair-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'Run-TestsInNavContainer' {
        $testResultsFile = Join-Path $navContainerPath "TestResults.xml"
        Run-TestsInNavContainer -containerName $navContainerName -credential $credential -detailed -XUnitResultFileName $testResultsFile
        [xml]$testResults = Get-Content $testResultsFile
        $testResults.assemblies.assembly.passed | Should -Be $testResults.assemblies.assembly.total
    }
    It 'Run-TestsInBcContainer' {
        $testResultsFile = Join-Path $bcContainerPath "TestResults.xml"
        Run-TestsInBcContainer -containerName $bcContainerName -credential $credential -detailed -XUnitResultFileName $testResultsFile -extensionId $bcAppId
        [xml]$testResults = Get-Content $testResultsFile
        $testResults.assemblies.assembly.passed | Should -Be $testResults.assemblies.assembly.total
    }
    It 'Start-NavContainerAppDataUpgrade' {
        #TODO
    }
    It 'Start-BcContainerAppDataUpgrade' {
        #TODO
    }
    It 'UnInstall-NavContainerApp' {
        UnInstall-NavContainerApp -containerName $navContainerName -appName $appName -appVersion $appVersion
    }
    It 'UnInstall-BcContainerApp' {
        UnInstall-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'UnPublish-NavContainerApp' {
        UnPublish-NavContainerApp -containerName $navContainerName -appName $appName
    }
    It 'UnPublish-BcContainerApp' {
        UnPublish-BcContainerApp -containerName $bcContainerName -appName $appName
    }

    It 'Create-AlProjectFolderFromBcContainer' {
        
        $TypeFolders = { Param ($type, $id, $name) 
            switch ($type) {
                "enum"           { "Enums\$($type) $($id) - $($name).al" }
                "enumextension"  { "Enums\$($type) $($id) - $($name).al" }
                "page"           { "Pages\$($type) $($id) - $($name).al" }
                "pageextension"  { "Pages\$($type) $($id) - $($name).al" }
                "table"          { "Tables\$($type) $($id) - $($name).al" }
                "tableexension"  { "Tables\$($type) $($id) - $($name).al" }
                "codeunit"       { "Codeunits\$($type) $($id) - $($name).al" }
                "interface"      { "Interfaces\$($type) $($id) - $($name).al" }
                "query"          { "Queries\$($type) $($id) - $($name).al" }
                "report"         { "Reports\$($type) $($id) - $($name).al" }
                "xmlport"        { "XmlPorts\$($type) $($id) - $($name).al" }
                "profile"        { "Profiles\$($name).Profile.al" }
                "dotnet"         { "$($name).al" }
                ".rdlc"          { "Layouts\$name$type" }
                ".docx"          { "Layouts\$name$type" }
                ".xlf"           { "Translations\$name$type" }
                default          { throw "Unknown type '$type'" }
            }
        }
        
        $alProjectFolder = Join-Path $bcContainerPath "mybaseapp"
        Create-AlProjectFolderFromBcContainer -containerName $bcContainerName `
                                              -alProjectFolder $alProjectFolder `
                                              -id ([Guid]::NewGuid().ToString()) `
                                              -name MyBaseApp `
                                              -publisher Freddy `
                                              -version "1.0.0.0" `
                                              -useBaseLine `
                                              -alFileStructure $TypeFolders

        (Get-ChildItem -Path (Join-Path $bcContainerPath "mybaseapp") -Recurse).Count | Should -BeGreaterThan 5000
    }
    It 'Compile/Publish-NewApplicationToBcContainer' {
        $alProjectFolder = Join-Path $bcContainerPath "mybaseapp"
        $appFile = Compile-AppInBCContainer -containerName $bcContainerName `
                                            -appProjectFolder $alProjectFolder `
                                            -appOutputFolder $alProjectFolder `
                                            -credential $credential `
                                            -updateSymbols

        Publish-NewApplicationToBcContainer -containerName $bcContainerName `
                                            -appFile $appFile `
                                            -credential $credential `
                                            -useCleanDatabase
    }

    It 'Get/RunTests for all versions' {
        $runTestsContainerName = "runtests"

        9,10,11,14,15,16,17 | % {

            
            $runTestsInVersion  = $_
            $artifactUrl = Get-BCArtifactUrl -type OnPrem -version "$runTestsInVersion" -country "w1" -select Latest
            $containerParams = @{ }
            if ($runTestsInVersion -lt 13) {
                $containerParams = @{ 
                    "includeCSIDE" = $true
                    "doNotExportObjectsToText" = $true
                }
            }

            New-BcContainer @containerParams -accept_eula `
                            -accept_outdated `
                            -containerName $runTestsContainerName `
                            -artifactUrl $artifactUrl `
                            -auth NavUserPassword `
                            -Credential $credential `
                            -updateHosts `
                            -licenseFile $licenseFile `
                            -includeTestToolkit

            $useCALTestFwk = $false
            if ($runTestsInVersion -lt 12) {
                Import-ObjectsToNavContainer -containerName $runTestsContainerName -objectsFile (Join-Path $PSScriptRoot "inserttests.txt") -sqlCredential $credential
                Compile-ObjectsInNavContainer -containerName $runTestsContainerName
                Invoke-NavContainerCodeunit -containerName $runTestsContainerName -Codeunitid 50000 -CompanyName "CRONUS International Ltd."
                $useCALTestFwk = $true
            }
            elseif ($runTestsInVersion -eq 14) {
                Copy-Item -Path (Join-Path $PSScriptRoot "inserttests") -Destination (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$runTestsContainerName") -Recurse -Force
                $appProjectFolder = Join-Path (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$runTestsContainerName") "inserttests"
                Compile-AppInBCContainer -containerName $runTestsContainerName -credential $credential -appProjectFolder $appProjectFolder -appOutputFolder $appProjectFolder -appName "inserttests.app" -UpdateSymbols
                Publish-NavContainerApp -containerName $runTestsContainerName -appFile (Join-Path $appProjectFolder "inserttests.app") -skipVerification -sync -install
                $useCALTestFwk = $true
            }

            if ($useCALTestFwk) {
                $tests = (Get-TestsFromBCContainer -containerName $runTestsContainerName -credential $credential).Codeunits
            }
            else {
                $tests = (Get-TestsFromBCContainer -containerName $runTestsContainerName -credential $credential -extensionId "fa3e2564-a39e-417f-9be6-c0dbe3d94069") | Where-Object { $_.id -eq 134006 -or $_.id -eq 134007 }
            }

            $tests.Count | Should -be 2
        
            $first = $true
            $resultsFile = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$runTestsContainerName\result.xml"
            $tests | % {
                $allpassed = Run-TestsInBcContainer -containerName $runTestsContainerName `
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
        Remove-NavContainer $runTestsContainerName
    }

    # Recreate contaminated containers
    . (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
    . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')
}