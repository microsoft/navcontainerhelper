Invoke-Pester -Script @{ "Path" = Join-Path $PSScriptRoot "_TestRunOne.ps1"; "Parameters" = @{ "licenseFile" = 'c:\temp\nchlicense.flf' } }
