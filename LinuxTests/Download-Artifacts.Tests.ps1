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

    It 'extracts Windows and standard ZIP paths into real directories' -Skip:(-not $IsLinux) {
        $zip = Join-Path $TestDrive 'platform.zip'
        $destination = Join-Path $TestDrive 'platform'
        New-TestZip $zip @('ServiceTier\program files\', 'ServiceTier\program files\Newtonsoft.Json.dll', 'Applications/Base.app')

        Push-Location $TestDrive
        try {
            InModuleScope BcContainerHelper {
                Expand-7zipArchive -Path 'platform.zip' -DestinationPath 'platform' -use7zipIfAvailable:$false
            }
        }
        finally {
            Pop-Location
        }

        Test-Path -LiteralPath (Join-Path $destination 'ServiceTier/program files/Newtonsoft.Json.dll') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $destination 'Applications/Base.app') -PathType Leaf | Should -BeTrue
    }

    It 'rejects an entry that would land outside the destination' -Skip:(-not $IsLinux) {
        $zip = Join-Path $TestDrive 'invalid.zip'
        $destination = Join-Path $TestDrive 'extraction'
        New-TestZip $zip @('..\outside.txt')

        InModuleScope BcContainerHelper -Parameters @{ Zip = $zip; Destination = $destination } {
            { Expand-7zipArchive -Path $Zip -DestinationPath $Destination -use7zipIfAvailable:$false } | Should -Throw '*outside the extraction directory*'
        }
        Test-Path -LiteralPath (Join-Path $TestDrive 'outside.txt') | Should -BeFalse
    }

    It 'redownloads an artifact once when extraction fails on Linux' -Skip:(-not $IsLinux) {
        $zip = Join-Path $TestDrive 'valid.zip'
        New-TestZip $zip @('ServiceTier\Newtonsoft.Json.dll')

        InModuleScope BcContainerHelper -Parameters @{ Zip = $zip; Cache = (Join-Path $TestDrive 'cache') } {
            $connections = $bcContainerHelperConfig.artifactDownloadConnections
            $bcContainerHelperConfig.artifactDownloadConnections = 0
            try {
                Mock Download-File {
                    param($destinationFile)
                    $marker = Join-Path $Cache 'first-attempt'
                    if (Test-Path -LiteralPath $marker) {
                        Copy-Item -LiteralPath $Zip -Destination $destinationFile
                    }
                    else {
                        New-Item -Path $marker -ItemType File | Out-Null
                        Set-Content -LiteralPath $destinationFile -Value 'invalid ZIP'
                    }
                }

                $artifact = Download-Artifacts -artifactUrl 'https://example.invalid/sandbox/22.0.54157.63994/base' -basePath $Cache

                Should -Invoke Download-File -Exactly -Times 2
                Test-Path -LiteralPath (Join-Path $artifact 'ServiceTier/Newtonsoft.Json.dll') -PathType Leaf | Should -BeTrue
            }
            finally {
                $bcContainerHelperConfig.artifactDownloadConnections = $connections
            }
        }
    }
}
