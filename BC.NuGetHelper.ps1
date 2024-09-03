# NuGet specific functions
if (-not (([System.Management.Automation.PSTypeName]"NuGetFeed").Type)) {
    . (Join-Path $PSScriptRoot "NuGet\NuGetFeedClass.ps1")
}
. (Join-Path $PSScriptRoot "NuGet\New-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Find-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Get-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Get-BcNuGetPackageId.ps1")
. (Join-Path $PSScriptRoot "NuGet\Push-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Publish-BcNuGetPackageToContainer.ps1")
. (Join-Path $PSScriptRoot "NuGet\Download-BcNuGetPackageToFolder.ps1")
