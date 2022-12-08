param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @()
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `
    -moduleDependencies @( 'BC.HelperFunctions' )

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# AppSource specific functions
. (Join-Path $PSScriptRoot "NuGet\New-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Get-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Push-BcNuGetPackage.ps1")
. (Join-Path $PSScriptRoot "NuGet\Publish-BcNuGetPackageToContainer.ps1")
