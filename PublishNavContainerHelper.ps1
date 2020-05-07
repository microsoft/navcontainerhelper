$path = $PSScriptRoot

$version = Get-Content -Path (Join-Path $path 'Version.txt')
Write-Host "NavContainerHelper version $Version"

$modulePath = Join-Path $path "NavContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking

$functionsToExport = (get-module -Name NavContainerHelper).ExportedFunctions.Keys | Sort-Object

$aliasesToExport = (get-module -Name NavContainerHelper).ExportedAliases.Keys | Sort-Object

$releaseNotes = Get-Content -Path (Join-Path $path "ReleaseNotes.txt")
$idx = $releaseNotes.IndexOf($version)
if ($idx -lt 0) {
    throw 'No release notes identified'
}
$versionReleaseNotes = @()
while ($releaseNotes[$idx]) {
    $versionReleaseNotes += $releaseNotes[$idx]
    $idx++
}

Write-Host "Release Notes:"
Write-Host $VersionReleaseNotes


Write-Host "Update Module Manifest"
Update-ModuleManifest -Path (Join-Path $path "NavContainerHelper.psd1") `
                      -RootModule "NavContainerHelper.psm1" `
                      -FileList @() `
                      -ModuleVersion $version `
                      -Author "Freddy Kristiansen" `
                      -FunctionsToExport $functionsToExport `
                      -AliasesToExport $aliasesToExport `
                      -CompanyName "Microsoft" `
                      -ReleaseNotes $versionReleaseNotes

Write-Host "Publishing Module"
#Publish-Module -Path $path -NuGetApiKey $(nugetkey)