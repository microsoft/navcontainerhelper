Describe 'AppHandling' {

    $appName = "Hello World"
    $appVersion = "1.0.0.0"

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
    }
    It 'Convert-ALCOutputToAzureDevOps' {
        #TODO
    }
    It 'Extract-AppFileToFolder (nav app)' {
        $navAppFile = Join-Path $navContainerPath "nav-app\output\Microsoft_$($appName)_$($appVersion).app"
        Extract-AppFileToFolder $navAppFile -appFolder (Join-Path $navContainerPath "nav-app2")
        (Get-ChildItem -Path (Join-Path $navContainerPath "nav-app2\*.al") -Recurse).Count | Should -Be (Get-ChildItem -Path (Join-Path $navContainerPath "nav-app\*.al") -Recurse).Count
    }
    It 'Extract-AppFileToFolder (bc app)' {
        $bcAppFile = Join-Path $bcContainerPath "bc-app\output\Microsoft_$($appName)_$($appVersion).app"
        Extract-AppFileToFolder $bcAppFile -appFolder (Join-Path $bcContainerPath "bc-app2")
        (Get-ChildItem -Path (Join-Path $bcContainerPath "bc-app\*.al") -Recurse).Count | Should -Be (Get-ChildItem -Path (Join-Path $bcContainerPath "bc-app2\*.al") -Recurse).Count

    }
    It 'Publish-NavContainerApp' {
        $navAppFile = Join-Path $navContainerPath "nav-app\output\Microsoft_Hello World_1.0.0.0.app"
        Publish-NavContainerApp -containerName $navContainerName -appFile $navAppFile -skipVerification
    }
    It 'Publish-BcContainerApp' {
        $bcAppFile = Join-Path $bcContainerPath "bc-app\output\Microsoft_Hello World_1.0.0.0.app"
        Publish-BcContainerApp -containerName $bcContainerName -appFile $bcAppFile -skipVerification
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
        Get-NavContainerApp -containerName $navContainerName -publisher Microsoft -appName $appName -appVersion $appVersion -credential $credential
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
        $tests = Get-TestsFromNavContainer -containerName $bcContainerName -credential $credential
        $tests.Tests | Should -Contain 'WorkingTest'
    }
    It 'Get-TestsFromBcContainer' {
        $tests = Get-TestsFromBcContainer -containerName $bcContainerName -credential $credential
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
        Run-TestsInBcContainer -containerName $bcContainerName -credential $credential -detailed -XUnitResultFileName $testResultsFile
        [xml]$testResults = Get-Content $testResultsFile
        $testResults.assemblies.assembly.passed | Should -Be $testResults.assemblies.assembly.total
    }
    It 'Sign-NavContainerApp' {
        #TODO
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

#    It 'Create-AlProjectFolderFromBcContainer' {
#        
#        $TypeFolders = { Param ($type, $id, $name) 
#            switch ($type) {
#                "page"     { "Pages\$($type) $($id) - $($name).al" }
#                "table"    { "Tables\$($type) $($id) - $($name).al" }
#                "codeunit" { "Codeunits\$($type) $($id) - $($name).al" }
#                "query"    { "Queries\$($type) $($id) - $($name).al" }
#                "report"   { "Reports\$($type) $($id) - $($name).al" }
#                "xmlport"  { "XmlPorts\$($type) $($id) - $($name).al" }
#                "profile"  { "Profiles\$($name).Profile.al" }
#                "dotnet"   { "$($name).al" }
#                ".rdlc"    { "Layouts\$name$type" }
#                ".docx"    { "Layouts\$name$type" }
#                ".xlf"     { "Translations\$name$type" }
#                default { throw "Unknown type '$type'" }
#            }
#        }
#                         
#        Create-AlProjectFolderFromBcContainer -containerName $bcContainerName `
#                                              -alProjectFolder (Join-Path $bcContainerPath "mybaseapp") `
#                                              -id ([Guid]::NewGuid().ToString()) `
#                                              -name MyBaseApp `
#                                              -publisher Freddy `
#                                              -version "1.0.0.0" `
#                                              -useBaseLine `
#                                              -alFileStructure $TypeFolders
#
#        (Get-ChildItem -Path (Join-Path $bcContainerPath "mybaseapp") -Recurse).Count | Should -BeGreaterThan 5000
#    }
    It 'Publish-NewApplicationToNavContainer' {
        #TODO
    }


    # Recreate contaminated containers
    #. (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
    #. (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')
}
