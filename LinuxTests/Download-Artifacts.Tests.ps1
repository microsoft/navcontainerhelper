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

    It 'extracts Windows and standard ZIP paths into real directories' -Skip:(-not ($PSVersionTable.PSVersion -ge '6.0.0' -and $isLinux)) {
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

    It 'rejects an entry that would land outside the destination' -Skip:(-not ($PSVersionTable.PSVersion -ge '6.0.0' -and $isLinux)) {
        $zip = Join-Path $TestDrive 'invalid.zip'
        $destination = Join-Path $TestDrive 'extraction'
        New-TestZip $zip @('..\outside.txt')

        InModuleScope BcContainerHelper -Parameters @{ Zip = $zip; Destination = $destination } {
            { Expand-7zipArchive -Path $Zip -DestinationPath $Destination -use7zipIfAvailable:$false } | Should -Throw '*outside the extraction directory*'
        }
        Test-Path -LiteralPath (Join-Path $TestDrive 'outside.txt') | Should -BeFalse
    }

    It 'reports the extraction error after <Attempts> download attempt(s) from <DownloadHost>' -ForEach @(
        @{ DownloadHost = 'example.invalid'; Attempts = 1 }
        @{ DownloadHost = 'example.azureedge.net'; Attempts = 2 }
    ) {
        InModuleScope BcContainerHelper -Parameters @{
            Cache = (Join-Path $TestDrive "cache-$Attempts")
            Url = "https://$DownloadHost/sandbox/22.0.54157.63994/base"
            Attempts = $Attempts
        } {
            $connections = $bcContainerHelperConfig.artifactDownloadConnections
            $bcContainerHelperConfig.artifactDownloadConnections = 0
            try {
                Mock Download-File {
                    param($destinationFile)
                    Set-Content -LiteralPath $destinationFile -Value 'invalid ZIP'
                }
                Mock Expand-7zipArchive {
                    throw 'Invalid ZIP archive'
                }

                { Download-Artifacts -artifactUrl $Url -basePath $Cache } |
                    Should -Throw 'Error trying to unpack artifact, downloaded package is corrupt. Error was Invalid ZIP archive'

                Should -Invoke Download-File -Exactly -Times $Attempts
                if ($Attempts -eq 2) {
                    Should -Invoke Download-File -Exactly -Times 1 -ParameterFilter {
                        $sourceUrl -eq 'https://example.blob.core.windows.net/sandbox/22.0.54157.63994/base'
                    }
                }
                Test-Path -LiteralPath (Join-Path $Cache 'sandbox/22.0.54157.63994/base') | Should -BeFalse
            }
            finally {
                $bcContainerHelperConfig.artifactDownloadConnections = $connections
            }
        }
    }
}
