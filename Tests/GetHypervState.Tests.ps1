Describe 'GetHypervState handles REGDB_E_CLASSNOTREG regardless of OS language (#4153)' {

    BeforeAll {
        $script:repoRoot = Split-Path -Parent $PSScriptRoot
        Remove-Module BcContainerHelper -ErrorAction Ignore
        Import-Module (Join-Path $repoRoot 'BcContainerHelper.psd1') -DisableNameChecking -Force
    }

    BeforeEach {
        # Reset module state so every test actually calls Get-WindowsOptionalFeature
        InModuleScope BcContainerHelper {
            $script:isAdministrator = $true
            $script:hypervState = 'Unknown'
        }
    }

    It 'returns Unknown for "Class not registered" in <Language>' -ForEach @(
        @{ Language = 'English'; Message = 'Class not registered' }
        @{ Language = 'German';  Message = 'Klasse nicht registriert' }
        @{ Language = 'Danish';  Message = 'Klassen er ikke registreret' }
    ) {
        # 0x80040154 = REGDB_E_CLASSNOTREG
        $mockBody = [scriptblock]::Create(
            "throw [System.Runtime.InteropServices.COMException]::new('$Message', -2147221164)"
        )

        InModuleScope BcContainerHelper -Parameters @{ MockBody = $mockBody } {
            Mock Get-WindowsOptionalFeature -MockWith $MockBody

            { GetHypervState } | Should -Not -Throw
            GetHypervState | Should -Be 'Unknown'
            Should -Invoke Get-WindowsOptionalFeature -Scope It
        }
    }

    It 'still throws on unrelated errors' {
        InModuleScope BcContainerHelper {
            # 0x80070005 = E_ACCESSDENIED
            Mock Get-WindowsOptionalFeature {
                throw [System.Runtime.InteropServices.COMException]::new('Access denied', -2147024891)
            }
            { GetHypervState } | Should -Throw
        }
    }

    It 'returns the feature state when the DISM call succeeds' {
        InModuleScope BcContainerHelper {
            Mock Get-WindowsOptionalFeature { [pscustomobject]@{ State = 'Enabled' } }
            GetHypervState | Should -Be 'Enabled'
        }
    }
}