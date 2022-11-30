param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @()
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `
    -moduleDependencies @( 'BC.ConfigurationHelper', 'BC.TelemetryHelper' )

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# Common functions
. (Join-Path $PSScriptRoot "Common\Download-File.ps1")
. (Join-Path $PSScriptRoot "Common\New-DesktopShortcut.ps1")
. (Join-Path $PSScriptRoot "Common\Remove-DesktopShortcut.ps1")
. (Join-Path $PSScriptRoot "Common\ConvertTo-HashTable.ps1")
. (Join-Path $PSScriptRoot "Common\Get-PlainText.ps1")
. (Join-Path $PSScriptRoot "Common\Invoke-gh.ps1")
. (Join-Path $PSScriptRoot "Common\Invoke-git.ps1")
. (Join-Path $PSScriptRoot "Common\ConvertTo-OrderedDictionary.ps1")
