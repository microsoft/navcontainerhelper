<#
.SYNOPSIS
    Prepares the BcContainerHelper module for release by copying files, cleaning up artifacts, and updating the module manifest.

.DESCRIPTION
    This script performs the following operations:
    1. Copies all BcContainerHelper files to the specified output directory
    2. Removes unnecessary files and folders (tests, CI/CD configs, git files)
    3. Extracts and sets the module version from Version.txt
    4. Imports the module and retrieves exported functions and aliases
    5. Retrieves the latest generic tag version from Business Central container images
    6. Extracts release notes for the current version
    7. Updates the module manifest (BcContainerHelper.psd1) with all metadata

    This script is designed to be used in the Azure DevOps release pipeline to prepare
    the module artifact before code signing and publishing.

.PARAMETER OutputPath
    The directory path where the prepared module files will be copied.
    This directory will be created if it doesn't exist.

.PARAMETER ProductionRelease
    Switch parameter indicating if this is a production release.

.EXAMPLE
    .\PrepareBCContainerHelperModule.ps1 -OutputPath "C:\Build\Output"

    Prepares the module with the standard version from Version.txt

.EXAMPLE
    .\PrepareBCContainerHelperModule.ps1 -OutputPath "C:\Build\Output" -ProductionRelease

    Prepares a production release version of the module.

.EXAMPLE
    .\PrepareBCContainerHelperModule.ps1 -OutputPath "$(Build.ArtifactStagingDirectory)/module"

    Prepares a preview module using Azure DevOps pipeline variables. The version will contain a suffix
    indicating it's a preview release.

.NOTES
    File Name      : PrepareBCContainerHelperModule.ps1
    Prerequisite   : Must be run from the repository root directory
    Requires       : BcContainerHelper module files must be present in the current directory
    Author         : Microsoft

.LINK
    https://github.com/microsoft/navcontainerhelper
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$ProductionRelease
)

$errorActionPreference = "Stop"

try {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

    Write-Host "Copying BCContainerHelper files to $OutputPath"
    $filesPath = '.'
    Get-ChildItem -Path $filesPath -Recurse | ForEach-Object { Write-Host $_.FullName }
    Copy-Item -Path (Join-Path $filesPath "*") -Destination $OutputPath -Recurse -Force

    Remove-Item -Path (Join-Path $OutputPath "Tests") -Force -Recurse -ErrorAction Ignore
    Remove-Item -Path (Join-Path $OutputPath "LinuxTests") -Force -Recurse -ErrorAction Ignore
    Remove-Item -Path (Join-Path $OutputPath "CODEOWNERS") -Force -Recurse -ErrorAction Ignore
    Remove-Item -Path (Join-Path $OutputPath ".github") -Force -Recurse -ErrorAction Ignore
    Remove-Item -Path (Join-Path $OutputPath ".azuredevops") -Force -Recurse -ErrorAction Ignore
    Remove-Item -Path (Join-Path $OutputPath ".git") -Force -Recurse -ErrorAction Ignore
    Remove-Item -Path (Join-Path $OutputPath ".gitignore") -Force -ErrorAction Ignore

    $versionFile = Join-Path $OutputPath 'Version.txt'
    $version = (Get-Content -Path $versionFile).split('-')[0]

    # Append preview suffix if this is not a production release
    if (-not $ProductionRelease) {
        $previewSuffix = "preview$($env:BUILD_BUILDID)"
        $fullVersion = "$version-$previewSuffix"
    }
    else {
        $fullVersion = $version
    }

    Write-Host "BcContainerHelper version $fullVersion"

    Set-Content -Path $versionFile -Value $fullVersion

    $modulePath = Join-Path $filesPath "BcContainerHelper.psm1"
    Import-Module $modulePath -DisableNameChecking

    $functionsToExport = (Get-Module -Name BcContainerHelper).ExportedFunctions.Keys | Sort-Object
    $aliasesToExport = (Get-Module -Name BcContainerHelper).ExportedAliases.Keys | Sort-Object

    $labels = Get-BcContainerImageLabels -imageName 'mcr.microsoft.com/businesscentral:ltsc2022'
    Write-Host "Set latest generic tag version to $($labels.tag)"
    Set-Content -Path (Join-Path $OutputPath 'LatestGenericTagVersion.txt') -value $labels.tag

    $releaseNotes = Get-Content -Path (Join-Path $OutputPath "ReleaseNotes.txt")
    $idx = $releaseNotes.IndexOf($version)
    if ($idx -lt 0) {
        throw "No release notes identified for version $version"
    }
    $versionReleaseNotes = @()
    while ($releaseNotes[$idx]) {
        $versionReleaseNotes += $releaseNotes[$idx]
        $idx++
    }

    Write-Host "Release Notes:"
    Write-Host $VersionReleaseNotes

    Write-Host "Update Module Manifest"
    $moduleManifestParams = @{
        Path              = Join-Path $OutputPath "BcContainerHelper.psd1"
        RootModule        = "BcContainerHelper.psm1"
        ModuleVersion     = $version
        Author            = "Microsoft"
        FunctionsToExport = $functionsToExport
        AliasesToExport   = $aliasesToExport
        CompanyName       = "Microsoft"
        ReleaseNotes      = $versionReleaseNotes
        LicenseUri        = 'https://github.com/microsoft/navcontainerhelper/blob/main/LICENSE'
        ProjectUri        = 'https://github.com/microsoft/navcontainerhelper'
    }

    if (-not $ProductionRelease) {
        $moduleManifestParams['Prerelease'] = $previewSuffix
    }

    Update-ModuleManifest @moduleManifestParams
}
catch {
    Write-Host "##vso[task.logissue type=error]Error preparing module. Error was: $($_.Exception.Message)"
    exit 1
}
