param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @()
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `
    -moduleDependencies @( 
        "BC.HelperFunctions",
        "BC.AuthenticationHelper",
        "BC.ArtifactsHelper",
        "BC.AppSourceHelper",
        "BC.ALGoHelper",
        "BC.SaasHelper",
        "BC.NuGetHelper"
    )
