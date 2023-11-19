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
    It 'Compile-AppInNavContainer generates error log file' {
        Copy-Item -Path (Join-Path $PSScriptRoot "nav-app") -Destination $navContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $navContainerPath "nav-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $navAppFile = Compile-AppInNavContainer -containerName $navContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -generateErrorLog -UpdateSymbols -credential $credential
        $navAppFile | Should -Exist

        $errorLogFile = $navAppFile -replace '.app$', '.errorLog.json'
        $errorLogFile | Should -Exist
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
}