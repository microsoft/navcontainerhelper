Param(
    [string] $licenseFile = "c:\temp\nchlicense.flf",
    [string] $buildlicenseFile = "c:\temp\build.flf",
    [string] $insiderSasToken = ""
)

. (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

$modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psm1"
Remove-Module BcContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking

$credential = [PSCredential]::new("admin", (ConvertTo-SecureString -AsPlainText -String "P@ssword1" -Force))

. (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
. (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')

. (Join-Path $PSScriptRoot "AppHandling.ps1")
