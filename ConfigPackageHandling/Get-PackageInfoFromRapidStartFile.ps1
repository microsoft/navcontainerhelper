<#
 .Synopsis
  Get a configuration package information from package file
 .Description
  Get a configuration package information from package file.
  Output:
    ExcludeConfigTables : 1
    LanguageID          : 1033
    ProductVersion      : W1_21.0.7.0
    PackageName         : My package Setup
    Code                : MYPACKAGE_SETUP
 .Parameter path
  Path to RapidStart package file
 .Example
  Get-PackageInfoFromRapidStartFile -path 'C:\temp\package.rapidstart'
#>
function Get-PackageInfoFromRapidStartFile {
    Param (
        [string] $path
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $packageFile = $null
        $gzipStream = $null
        $buffer = $null
        $packageInfo = $null
        $packageFile = New-Object System.IO.FileStream $path, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
        $gzipStream = New-Object System.IO.Compression.GzipStream $packageFile, ([IO.Compression.CompressionMode]::Decompress)
        $buffer = New-Object byte[](1024)
        while ($true) {
            $read = $gzipstream.Read($buffer, 0, 1024)
            if ($read -le 0) { break }
            $readText = [System.Text.Encoding]::Unicode.GetString($buffer)
            $readText.Split([Environment]::NewLine) | ForEach-Object {
                if ($_.IndexOf('DataList') -ne -1 ) {
                    [xml]$package = ($_ + '</DataList>')
                    $packageInfo = $package.'DataList'
                    break
                }
            }
        }
        return $packageInfo
    }
    catch {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
        throw
    }
    finally {
        if ($gzipStream) {
            $gzipStream.Close()
        }
        if ($packageFile) {
            $packageFile.Close()
        }
        TrackTrace -telemetryScope $telemetryScope
    }
}
Export-ModuleMember -Function Get-PackageInfoFromRapidStartFile
