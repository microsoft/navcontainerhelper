Param(
    [string] $licenseFile = "c:\temp\nchlicense.flf",
    [string] $buildlicenseFile = "c:\temp\build.flf",
    [string] $insiderSasToken = ""
)

. (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

$modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psm1"
Remove-Module BcContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking

$credential = [PSCredential]::new("admin", (Get-RandomPasswordAsSecureString))

Get-BcContainers | Remove-BCContainer
Flush-ContainerHelperCache

. (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
. (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')

try {
    Get-ChildItem -Path (Join-Path $PSScriptRoot '*.ps1') -Exclude @("_*.ps1") | % {
        . $_.FullName
    }
}
finally {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
    . (Join-Path $PSScriptRoot '_RemoveNavContainer.ps1')
}
