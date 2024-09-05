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
. (Join-Path $PSScriptRoot "SaaSHelperFunctions.ps1")
. (Join-Path $PSScriptRoot "BC.NuGetHelper.ps1")
