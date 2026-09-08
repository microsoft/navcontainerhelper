Describe 'PS7 remote-session guard (BC v27+)' {

    BeforeAll {
        $script:repoRoot = Split-Path -Parent $PSScriptRoot
        $script:guardFile = Join-Path $repoRoot 'ContainerHandling\Invoke-ScriptInNavContainer.ps1'
        $script:configFile = Join-Path $repoRoot 'BC.HelperFunctions.ps1'
        $script:releaseNotes = Join-Path $repoRoot 'ReleaseNotes.txt'

        # Faithful replica of the guard decision in Invoke-ScriptInNavContainer.ps1.
        # A source-content test below asserts the real source still matches this predicate,
        # so this replica cannot silently drift from the shipped code.
        # Each flag governs its own version band independently:
        #   usePsSessionForBc27 -> BC v27 only
        #   usePsSessionForBc28 -> BC v28 and later
        function Get-EffectiveUseSession {
            param(
                [int]  $major,
                [bool] $useSession,
                [bool] $usePwsh,
                [hashtable] $config
            )
            if ($useSession -and $usePwsh) {
                if (($major -eq 27 -and -not $config.usePsSessionForBc27) -or
                    ($major -ge 28 -and -not $config.usePsSessionForBc28)) {
                    $useSession = $false
                }
            }
            return $useSession
        }
    }

    Context 'Source files are valid and consistent' {

        It 'Invoke-ScriptInNavContainer.ps1 parses without errors' {
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($guardFile, [ref]$null, [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }

        It 'BC.HelperFunctions.ps1 parses without errors' {
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($configFile, [ref]$null, [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }

        It 'guard source uses independent per-version-band logic for both flags' {
            $content = Get-Content -Raw -Path $guardFile
            $content | Should -Match '\$platformVersion\.Major\s+-eq\s+27\s+-and\s+-not\s+\$bcContainerHelperConfig\.usePsSessionForBc27'
            $content | Should -Match '\$platformVersion\.Major\s+-ge\s+28\s+-and\s+-not\s+\$bcContainerHelperConfig\.usePsSessionForBc28'
        }

        It 'config default exposes both usePsSessionForBc27 and usePsSessionForBc28' {
            $content = Get-Content -Raw -Path $configFile
            $content | Should -Match '"usePsSessionForBc27"\s*=\s*\$false'
            $content | Should -Match '"usePsSessionForBc28"\s*=\s*\$false'
        }

        It 'ReleaseNotes documents the v27+ change and both flags' {
            $content = Get-Content -Raw -Path $releaseNotes
            $content | Should -Match 'usePsSessionForBc27'
            $content | Should -Match 'usePsSessionForBc28'
            $content | Should -Match 'v27'
        }
    }

    Context 'Guard decision truth table (usePwsh enabled)' {

        It 'disables the session for BC v27 with default config (docker exec fallback)' {
            $config = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 27 -useSession $true -usePwsh $true -config $config | Should -BeFalse
        }

        It 'keeps the session enabled for BC v27 when usePsSessionForBc27 escape hatch is set' {
            $config = @{ usePsSessionForBc27 = $true; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 27 -useSession $true -usePwsh $true -config $config | Should -BeTrue
        }

        It 'still disables BC v27 when only usePsSessionForBc28 is set (28 flag must not re-enable v27)' {
            $config = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $true }
            Get-EffectiveUseSession -major 27 -useSession $true -usePwsh $true -config $config | Should -BeFalse
        }

        It 'disables the session for BC v28 with default config' {
            $config = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 28 -useSession $true -usePwsh $true -config $config | Should -BeFalse
        }

        It 'keeps the session enabled for BC v28 when usePsSessionForBc28 escape hatch is set' {
            $config = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $true }
            Get-EffectiveUseSession -major 28 -useSession $true -usePwsh $true -config $config | Should -BeTrue
        }

        It 'still disables BC v28 when only usePsSessionForBc27 is set (27 flag must not re-enable v28)' {
            $config = @{ usePsSessionForBc27 = $true; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 28 -useSession $true -usePwsh $true -config $config | Should -BeFalse
        }

        It 'disables BC v29 and v30 by default and honors usePsSessionForBc28 for v29+' {
            $defaultConfig = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 29 -useSession $true -usePwsh $true -config $defaultConfig | Should -BeFalse
            Get-EffectiveUseSession -major 30 -useSession $true -usePwsh $true -config $defaultConfig | Should -BeFalse
            $enabledConfig = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $true }
            Get-EffectiveUseSession -major 29 -useSession $true -usePwsh $true -config $enabledConfig | Should -BeTrue
        }

        It 'leaves the session enabled for BC versions below v27' {
            $config = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 26 -useSession $true -usePwsh $true -config $config | Should -BeTrue
            Get-EffectiveUseSession -major 24 -useSession $true -usePwsh $true -config $config | Should -BeTrue
        }

        It 'does not touch the session when usePwsh is disabled' {
            $config = @{ usePsSessionForBc27 = $false; usePsSessionForBc28 = $false }
            Get-EffectiveUseSession -major 27 -useSession $true -usePwsh $false -config $config | Should -BeTrue
            Get-EffectiveUseSession -major 28 -useSession $true -usePwsh $false -config $config | Should -BeTrue
        }
    }
}
