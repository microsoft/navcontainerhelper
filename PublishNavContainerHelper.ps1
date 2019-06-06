$VerbosePreference="SilentlyContinue"

# Version, Author, CompanyName and nugetkey
. (Join-Path $PSScriptRoot "settings.ps1")

Clear-Host
#Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings PSGallery -Severity Warning

Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Remove-Module NavContainerHelper -ErrorAction Ignore
Uninstall-module NavContainerHelper -ErrorAction Ignore

$path = "c:\temp\NavContainerHelper"

if (Test-Path -Path $path) {
    Remove-Item -Path $path -Force -Recurse
}
Copy-Item -Path $PSScriptRoot -Destination "c:\temp" -Exclude @("settings.ps1", ".gitignore", "README.md", "PublishNavContainerHelper.ps1") -Recurse
Remove-Item -Path (Join-Path $path ".git") -Force -Recurse
Remove-Item -Path (Join-Path $path "Tests") -Force -Recurse

$modulePath = Join-Path $path "NavContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking

$functionsToExport = (get-module -Name NavContainerHelper).ExportedFunctions.Keys | Sort-Object
$aliasesToExport = (get-module -Name NavContainerHelper).ExportedAliases.Keys | Sort-Object

Update-ModuleManifest -Path (Join-Path $path "NavContainerHelper.psd1") `
                      -RootModule "NavContainerHelper.psm1" `
                      -FileList @("ContainerHandling\docker.ico") `
                      -ModuleVersion $version `
                      -Author $author `
                      -FunctionsToExport $functionsToExport `
                      -AliasesToExport $aliasesToExport `
                      -CompanyName $CompanyName `
                      -ReleaseNotes (get-content (Join-Path $path "ReleaseNotes.txt")) 

#Publish-Module -Path $path -NuGetApiKey $nugetkey

Remove-Item -Path $path -Force -Recurse
