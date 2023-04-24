Param(
    [string] $licenseFile = ($nchLicensefileSecret.secretValue | Get-PlainText),
    [string] $buildlicenseFile = ($LicensefileSecret.secretValue | Get-PlainText),
    [string] $insiderSasToken = ($InsiderSasTokenSecret.SecretValue | Get-PlainText),
    [string] $testScript = "AppHandling.ps1"
)

try {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

    $modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psm1"
    Remove-Module BcContainerHelper -ErrorAction Ignore
    Import-Module $modulePath -DisableNameChecking

    . (Join-Path $PSScriptRoot $testScript)
}
catch {
    Write-Host "::Error::$($_.Exception.Message)"
}
