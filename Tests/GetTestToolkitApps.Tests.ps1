BeforeAll {
    $helperFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'HelperFunctions.ps1'
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($helperFile, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw ($parseErrors | Out-String)
    }
    # Load the shipped functions without initializing the module or requiring Docker.
    $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -in @('GetSymbolFiles', 'GetTestToolkitApps')
    }, $false) | ForEach-Object {
        . ([scriptblock]::Create($_.Extent.Text))
    }

    function Invoke-ScriptInBCContainer {
        param($containerName, $scriptblock, $argumentList)
        & $scriptblock @argumentList
    }

    function Get-AppJsonFromAppFile {
        param($appFile)
        @{ version = '30.0.0.0' }
    }

    $script:applications = Join-Path $TestDrive 'Applications'
    $script:runnerNames = @(
        'Microsoft_Test Runner.app'
        'Microsoft_Test Runner_30.0.57750.0.app'
        'Microsoft_Test Runner Helper.app'
        'Microsoft_Test Runner Tests Helper.app'
    )
    $script:excludedNames = @(
        'Microsoft_Test Runner Tests.app'
        'Microsoft_Test Runner Tests_30.0.57750.0.app'
        'microsoft_test runner tests_30.1.0.0.app'
    )
    $fixturePaths = @(
        'TestFramework\TestLibraries\permissions mock\Microsoft_Permissions Mock.app'
        'TestFramework\TestLibraries\Microsoft_Library Assert.app'
        'TestFramework\PerformanceToolkit\Microsoft_Performance Toolkit.app'
        'TestFramework\PerformanceToolkit\Microsoft_Performance Toolkit Tests.app'
        'Libraries\Microsoft_Application Test Library.app'
        'Tests\Microsoft_Tests-Sample.app'
    )
    $fixturePaths += $runnerNames | ForEach-Object { "TestFramework\TestRunner\Nested\$_" }
    $fixturePaths += $excludedNames | ForEach-Object { "TestFramework\TestRunner\Tests\$_" }
    foreach ($relativePath in $fixturePaths) {
        $path = Join-Path $applications $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        New-Item -ItemType File -Path $path | Out-Null
    }
}

Describe 'GetTestToolkitApps' {
    BeforeEach {
        Mock Get-Item {
            [pscustomobject]@{ VersionInfo = [pscustomobject]@{ FileVersion = '30.0.57750.0' } }
        } -ParameterFilter { $Path -like 'C:\Program Files\Microsoft Dynamics NAV\*' }
        Mock Test-Path { $true } -ParameterFilter {
            $Path -eq 'C:\Applications\TestFramework\TestLibraries\permissions mock'
        }
        Mock Get-ChildItem {
            param($Path, $Filter, [switch]$Recurse, $Exclude)
            if ($Path -like 'C:\applications.*\*') {
                return
            }
            $localPath = $Path.Replace('C:\Applications', $applications)
            Microsoft.PowerShell.Management\Get-ChildItem -Path $localPath -Filter $Filter -Recurse:$Recurse -Exclude $Exclude
        } -ParameterFilter { $Path -like 'C:\Applications\*' -or $Path -like 'C:\applications.*\*' }
    }

    It 'excludes runner regression apps and preserves toolkit selection in <mode> mode' -TestCases @(
        @{ mode = 'all'; options = @{}; libraries = $true; tests = $true; framework = $true }
        @{ mode = 'runner-only'; options = @{ includeTestRunnerOnly = $true }; libraries = $false; tests = $false; framework = $false }
        @{ mode = 'framework-only'; options = @{ includeTestFrameworkOnly = $true }; libraries = $false; tests = $false; framework = $true }
        @{ mode = 'libraries-only'; options = @{ includeTestLibrariesOnly = $true }; libraries = $true; tests = $false; framework = $true }
    ) {
        param($options, $libraries, $tests, $framework)
        $result = @(GetTestToolkitApps -containerName 'mock-container' @options)
        $names = @($result | ForEach-Object { Split-Path -Leaf $_ })
        foreach ($name in $excludedNames) {
            $names | Should -Not -Contain $name
            Join-Path $applications "TestFramework\TestRunner\Tests\$name" | Should -Exist
        }
        foreach ($name in $runnerNames) {
            $names | Should -Contain $name
        }
        $names | Should -Contain 'Microsoft_Permissions Mock.app'
        ($names -contains 'Microsoft_Library Assert.app') | Should -Be $framework
        ($names -contains 'Microsoft_Application Test Library.app') | Should -Be $libraries
        ($names -contains 'Microsoft_Tests-Sample.app') | Should -Be $tests
        $names | Should -Not -Contain 'Microsoft_Performance Toolkit.app'
    }

    It 'preserves optional performance toolkit selection in <mode> mode' -TestCases @(
        @{ mode = 'all'; options = @{}; performanceTests = $true }
        @{ mode = 'framework-only'; options = @{ includeTestFrameworkOnly = $true }; performanceTests = $false }
    ) {
        param($options, $performanceTests)
        $names = @(GetTestToolkitApps -containerName 'mock-container' -includePerformanceToolkit @options |
            ForEach-Object { Split-Path -Leaf $_ })
        $names | Should -Contain 'Microsoft_Performance Toolkit.app'
        ($names -contains 'Microsoft_Performance Toolkit Tests.app') | Should -Be $performanceTests
        foreach ($name in $excludedNames) {
            $names | Should -Not -Contain $name
        }
    }

    It 'keeps compiler-folder runner selection unchanged' {
        $compilerFolder = Join-Path $TestDrive 'compiler'
        $symbols = Join-Path $compilerFolder 'symbols'
        New-Item -ItemType Directory -Path $symbols -Force | Out-Null
        foreach ($name in @('Microsoft_Base Application.app', 'Microsoft_Permissions Mock.app') + $runnerNames + $excludedNames) {
            New-Item -ItemType File -Path (Join-Path $symbols $name) -Force | Out-Null
        }
        $names = @(GetTestToolkitApps -compilerFolder $compilerFolder -includeTestRunnerOnly |
            ForEach-Object { Split-Path -Leaf $_ })
        $names.Count | Should -Be 2
        $names | Should -Contain 'Microsoft_Permissions Mock.app'
        $names | Should -Contain 'Microsoft_Test Runner_30.0.57750.0.app'
    }
}
