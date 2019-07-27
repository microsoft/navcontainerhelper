Param(
    [string] $licenseFile = "c:\temp\build.flf"
)

. (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

$modulePath = Join-Path $PSScriptRoot "..\NavContainerHelper.psm1"
Remove-Module NavContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking

$credential = [PSCredential]::new("admin", (ConvertTo-SecureString -AsPlainText -String "P@ssword1" -Force))

. (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')
. (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')

. (Join-Path $PSScriptRoot "ObjectHandling.ps1")
