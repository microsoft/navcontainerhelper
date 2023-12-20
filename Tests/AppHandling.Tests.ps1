Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')
    $appPublisher = "Cronus Denmark A/S"
    $appName = "Hello ÆØÅ"
    $appVersion = "1.0.0.0"
    $bcAppId = "cb99d78b-f9db-4a1e-822a-0c9c444535df"
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
}

Describe 'AppHandling' {

    It 'Add-GitToAlProjectFolder' {
        #TODO
    }
    It 'Clean-BcContainerDatabase' {
        #TODO
    }
    It 'Compile-AppInNavContainer generates error log file' {
        Copy-Item -Path (Join-Path $PSScriptRoot "bc-app") -Destination $bcContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $bcContainerPath "bc-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $bcAppFile = Compile-AppInBcContainer -containerName $bcContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols -credential $credential -generateErrorLog
        $bcAppFile | Should -Exist

        $errorLogFile = $bcAppFile -replace '.app$', '.errorLog.json'
        $errorLogFile | Should -Exist
    }
    It 'Compile-AppInBcContainer' {
        Copy-Item -Path (Join-Path $PSScriptRoot "bc-app") -Destination $bcContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $bcContainerPath "bc-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $bcAppFile = Compile-AppInBcContainer -containerName $bcContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols -credential $credential
        $bcAppFile | Should -Exist

        Publish-BcContainerApp -containerName $bcContainerName -appFile $bcAppFile -skipVerification -sync -install

        Copy-Item -Path (Join-Path $PSScriptRoot "bc2-app") -Destination $bcContainerPath -Recurse -Force
        $appProjectFolder = Join-Path $bcContainerPath "bc2-app"
        $appOutputFolder = Join-Path $appProjectFolder "output"
        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

        $bc2AppFile = Compile-AppInBcContainer -containerName $bcContainerName -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols -credential $credential
        $bc2AppFile | Should -Exist

        UnPublish-BCContainerApp -containerName $bcContainerName -appName $appName -publisher $appPublisher -version $appVersion -unInstall -doNotSaveData
    }
    It 'Convert-ALCOutputToAzureDevOps' {
        #TODO
    }
    It 'Copy-AlSourceFiles' {
        #TODO
    }
    It 'Extract-AppFileToFolder (bc app)' {
        $bcAppFileName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        $bcAppFile = Join-Path $bcContainerPath "bc-app\output\$bcAppFileName"
        Extract-AppFileToFolder $bcAppFile -appFolder (Join-Path $bcContainerPath "bc-app2")
        (Get-ChildItem -Path (Join-Path $bcContainerPath "bc-app\*.al") -Recurse).Count | Should -Be (Get-ChildItem -Path (Join-Path $bcContainerPath "bc-app2\*.al") -Recurse).Count
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
    It 'Sync-BcContainerApp' {
        Sync-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'Install-BcContainerApp' {
        Install-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'Get-BcContainerAppInfo' {
        $myapp = Get-BcContainerAppInfo -containerName $bcContainerName | Where-Object { $_.Name -eq $appName }
        $myapp | Should -not -BeNullOrEmpty
    }
    It 'Get-TestsFromBcContainer' {
        $tests = Get-TestsFromBcContainer -containerName $bcContainerName -credential $credential -extensionId $bcAppId
        $tests.Tests | Should -Contain 'WorkingTest'
    }
    It 'Repair-BcContainerApp' {
        Repair-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
    }
    It 'Run-TestsInBcContainer' {
        $testResultsFile = Join-Path $bcContainerPath "TestResults.xml"
        Run-TestsInBcContainer -containerName $bcContainerName -credential $credential -detailed -XUnitResultFileName $testResultsFile -extensionId $bcAppId
        [xml]$testResults = Get-Content $testResultsFile
        $testResults.assemblies.assembly.passed | Should -Be $testResults.assemblies.assembly.total
    }
    It 'Start-BcContainerAppDataUpgrade' {
        #TODO
    }
    It 'UnInstall-BcContainerApp' {
        UnInstall-BcContainerApp -containerName $bcContainerName -appName $appName -appVersion $appVersion
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
        
#        Publish-NewApplicationToBcContainer -containerName $bcContainerName `
#                                            -appFile $appFile `
#                                            -credential $credential `
#                                            -useCleanDatabase
    }
}