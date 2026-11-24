Describe 'BC artifact ZIP extraction' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../BcContainerHelper.psd1') -DisableNameChecking -Force

        function New-TestZip([string] $path, [string[]] $names) {
            $archive = [System.IO.Compression.ZipFile]::Open($path, 'Create')
            try {
                foreach ($name in $names) {
                    $null = $archive.CreateEntry($name)
                }
            }
            finally {
                $archive.Dispose()
            }
        }
    }

    It 'extracts Windows and standard ZIP paths into real directories' {
        $zip = Join-Path $TestDrive 'platform.zip'
        $destination = Join-Path $TestDrive 'platform'
        New-TestZip $zip @('ServiceTier\program files\', 'ServiceTier\program files\Newtonsoft.Json.dll', 'Applications/Base.app')

        InModuleScope BcContainerHelper -Parameters @{ Zip = $zip; Destination = $destination } {
            Expand-BcArtifactArchiveOnLinux -Path $Zip -DestinationPath $Destination
        }

        Test-Path -LiteralPath (Join-Path $destination 'ServiceTier/program files/Newtonsoft.Json.dll') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $destination 'Applications/Base.app') -PathType Leaf | Should -BeTrue
    }

    It 'rejects an entry that would land outside the destination' {
        $zip = Join-Path $TestDrive 'invalid.zip'
        $destination = Join-Path $TestDrive 'extraction'
        New-TestZip $zip @('..\outside.txt')

        InModuleScope BcContainerHelper -Parameters @{ Zip = $zip; Destination = $destination } {
            { Expand-BcArtifactArchiveOnLinux -Path $Zip -DestinationPath $Destination } | Should -Throw '*outside the extraction directory*'
        }
        Test-Path -LiteralPath (Join-Path $TestDrive 'outside.txt') | Should -BeFalse
    }
}
