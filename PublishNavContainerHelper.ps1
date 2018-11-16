$VerbosePreference="SilentlyContinue"

# Version, Author, CompanyName and nugetkey
. (Join-Path $PSScriptRoot "settings.ps1")

Clear-Host
#Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings PSGallery -Severity Warning

. (Join-Path $PSScriptRoot "NavContainerHelper.ps1")
$functionsToExport = (get-module -Name NavContainerHelper).ExportedFunctions.Keys | Sort-Object
Update-ModuleManifest -Path (Join-Path $PSScriptRoot "NavContainerHelper.psd1") `
                      -RootModule "NavContainerHelper.psm1" `
                      -FileList @("ContainerHandling\docker.ico") `
                      -ModuleVersion $version `
                      -Author $author `
                      -FunctionsToExport $functionsToExport `
                      -CompanyName $CompanyName `
                      -ReleaseNotes (get-content (Join-Path $PSScriptRoot "ReleaseNotes.txt")) 

Publish-Module -Path $PSScriptRoot -NuGetApiKey $nugetkey
