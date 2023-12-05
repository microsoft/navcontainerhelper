Param(
    [string] $licenseFile = ($nchLicensefileSecret.secretValue | Get-PlainText),
    [string] $buildlicenseFile = ($LicensefileSecret.secretValue | Get-PlainText),
    [string] $testScript = "AppHandling.Tests.ps1"
)

try {
    Write-Host $buildlicenseFile

    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

    $modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psm1"
    Remove-Module BcContainerHelper -ErrorAction Ignore
    Import-Module $modulePath -DisableNameChecking

    . (Join-Path $PSScriptRoot $testScript) -licenseFile $licenseFile -buildlicenseFile $buildlicenseFile
}
catch {
    Write-Host "::Error::$($_.Exception.Message)"
}
