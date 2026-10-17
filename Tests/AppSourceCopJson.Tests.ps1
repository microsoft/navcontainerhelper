# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.

Describe 'Run-AlPipeline AppSourceCop configuration' {
    BeforeAll {
        # Execute the actual generation block independently of Docker and the AL compiler.
        $source = Join-Path (Split-Path -Parent $PSScriptRoot) 'AppHandling/Run-AlPipeline.ps1'
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) { throw $parseErrors[0] }
        $blocks = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and
                $node.Clauses[0].Item1.Extent.Text -eq '$enableAppSourceCop -and $app'
        }, $true))
        if ($blocks.Count -ne 1) { throw 'Expected one AppSourceCop generation block' }
        $generate = [scriptblock]::Create($blocks[0].Extent.Text)
    }

    BeforeEach {
        $folder = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $folder
        $jsonPath = Join-Path $folder 'AppSourceCop.json'
        $enableAppSourceCop = $true
        $app = $true
        $AppSourceCopMandatoryAffixes = @()
        $AppSourceCopSupportedCountries = @()
        $ObsoleteTagMinAllowedMajorMinor = ''
        $previousAppVersions = @{}
        $appJson = @{ Publisher = 'Publisher'; Name = 'Application' }
        Mock Write-Host {}
        Mock Out-Host {}
    }

    It 'preserves user-managed properties when mandatory affixes are configured' {
        @{
            mandatoryPrefix = 'ABC'
            supportedCountries = @('DE', 'AT', 'CH')
            custom = @{ enabled = $false; label = 'München'; values = @() }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
        $AppSourceCopMandatoryAffixes = @('ABC')

        & $generate

        $result = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $result.mandatoryPrefix | Should -Be 'ABC'
        ($result.supportedCountries -join ',') | Should -Be 'DE,AT,CH'
        @($result.mandatoryAffixes).Count | Should -Be 1
        $result.mandatoryAffixes[0] | Should -Be 'ABC'
        $result.custom.enabled | Should -BeFalse
        $result.custom.label | Should -Be 'München'
        @($result.custom.values).Count | Should -Be 0
    }

    It 'retains an existing configuration when no managed settings are supplied' {
        '{"supportedCountries":["DE"],"mandatoryPrefix":"ABC"}' |
            Set-Content -LiteralPath $jsonPath -Encoding UTF8

        & $generate

        Test-Path $jsonPath | Should -BeTrue
        $result = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $result.mandatoryPrefix | Should -Be 'ABC'
        $result.supportedCountries[0] | Should -Be 'DE'
    }

    It 'overwrites managed properties without discarding unrelated settings' {
        @{
            mandatoryAffixes = @('OLD'); supportedCountries = @('US')
            obsoleteTagMinAllowedMajorMinor = '1.0'
            publisher = 'Old'; name = 'Old'; version = '1.0.0.0'
            custom = 'keep'
        } | ConvertTo-Json | Set-Content -LiteralPath $jsonPath -Encoding UTF8
        $AppSourceCopMandatoryAffixes = @('NEW')
        $AppSourceCopSupportedCountries = @('DE', 'AT')
        $ObsoleteTagMinAllowedMajorMinor = '2.0'
        $previousAppVersions = @{ 'Publisher_Application' = '2.0.0.0' }

        & $generate

        $result = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $result.mandatoryAffixes[0] | Should -Be 'NEW'
        ($result.supportedCountries -join ',') | Should -Be 'DE,AT'
        $result.obsoleteTagMinAllowedMajorMinor | Should -Be '2.0'
        $result.Publisher | Should -Be 'Publisher'
        $result.Name | Should -Be 'Application'
        $result.Version | Should -Be '2.0.0.0'
        $result.custom | Should -Be 'keep'
    }

    It 'still creates a configuration when the file does not exist' {
        $AppSourceCopMandatoryAffixes = @('ABC')
        & $generate
        $result = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $result.mandatoryAffixes[0] | Should -Be 'ABC'
    }

    It 'does not create an empty configuration without managed settings' {
        & $generate
        Test-Path $jsonPath | Should -BeFalse
    }

    It 'leaves the file unchanged when AppSourceCop is disabled or this is a test app' -TestCases @(
        @{ enabled = $false; isApp = $true }
        @{ enabled = $true; isApp = $false }
    ) {
        param($enabled, $isApp)
        $enableAppSourceCop = $enabled
        $app = $isApp
        $AppSourceCopMandatoryAffixes = @('NEW')
        $original = '{"mandatoryPrefix":"ABC"}'
        Set-Content -LiteralPath $jsonPath -Value $original -Encoding UTF8 -NoNewline
        & $generate
        Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | Should -Be $original
    }

    It 'does not overwrite a malformed existing configuration' {
        $original = '{ invalid json'
        Set-Content -LiteralPath $jsonPath -Value $original -Encoding UTF8 -NoNewline
        $AppSourceCopMandatoryAffixes = @('ABC')
        { & $generate } | Should -Throw
        Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | Should -Be $original
    }
    It 'preserves an explicitly empty configuration' {
        Set-Content -LiteralPath $jsonPath -Value '{}' -Encoding UTF8
        & $generate
        Test-Path $jsonPath | Should -BeTrue
        $result = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        @($result.PSObject.Properties).Count | Should -Be 0
    }

    It 'rejects a non-object JSON configuration without overwriting it' -TestCases @(
        @{ original = '[]' }
        @{ original = '[{}]' }
        @{ original = 'null' }
        @{ original = '1' }
        @{ original = '"text"' }
    ) {
        param($original)
        Set-Content -LiteralPath $jsonPath -Value $original -Encoding UTF8 -NoNewline
        $AppSourceCopMandatoryAffixes = @('ABC')
        { & $generate } | Should -Throw '*must be a JSON object*'
        Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | Should -Be $original
    }

}
