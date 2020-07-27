$path = $PSScriptRoot

$versionTxt = Get-Content -Path (Join-Path $path 'Version.txt')
Write-Host "BcContainerHelper version $VersionTxt"

$version = "$versionTxt-".Split('-')[0]
$prerelease = "$versionTxt-".Split('-')[1]

$modulePath = Join-Path $path "BcContainerHelper.psm1"
Import-Module $modulePath -DisableNameChecking

$functionsToExport = (get-module -Name BcContainerHelper).ExportedFunctions.Keys | Sort-Object

$aliasesToExport = (get-module -Name BcContainerHelper).ExportedAliases.Keys | Sort-Object

$releaseNotes = Get-Content -Path (Join-Path $path "ReleaseNotes.txt")
$idx = $releaseNotes.IndexOf($versionTxt)
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
Update-ModuleManifest -Path (Join-Path $path "BcContainerHelper.psd1") `
                      -RootModule "BcContainerHelper.psm1" `
                      -ModuleVersion $version `
                      -Prerelease $prerelease `
                      -Author "Freddy Kristiansen" `
                      -FunctionsToExport $functionsToExport `
                      -AliasesToExport $aliasesToExport `
                      -CompanyName "Microsoft" `
                      -ReleaseNotes $versionReleaseNotes

Write-Host "Publishing Module"
#Publish-Module -Path $path -NuGetApiKey $(nugetkey)