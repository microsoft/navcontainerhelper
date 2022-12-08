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
. (Join-Path $PSScriptRoot "AppSource\Invoke-IngestionAPI.ps1")
. (Join-Path $PSScriptRoot "AppSource\Get-AppSourceProduct.ps1")
. (Join-Path $PSScriptRoot "AppSource\Get-AppSourceSubmission.ps1")
. (Join-Path $PSScriptRoot "AppSource\New-AppSourceSubmission.ps1")
. (Join-Path $PSScriptRoot "AppSource\Promote-AppSourceSubmission.ps1")
. (Join-Path $PSScriptRoot "AppSource\Cancel-AppSourceSubmission.ps1")
