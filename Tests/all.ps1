# Run all tests

$credential = Get-Credential -Username $env:USERNAME -Message "Enter a set of credentials to use for containers in the tests"

. (Join-Path $PSScriptRoot "Happy-path\test.ps1")
. (Join-Path $PSScriptRoot "ExternalSQL\test.ps1")
. (Join-Path $PSScriptRoot "Generic\test.ps1")
. (Join-Path $PSScriptRoot "Multitenancy\test.ps1")
. (Join-Path $PSScriptRoot "Versions\test.ps1")
