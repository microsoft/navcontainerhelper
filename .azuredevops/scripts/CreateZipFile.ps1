<#
.SYNOPSIS
    Creates a versioned zip file of the BcContainerHelper module.

.DESCRIPTION
    This script reads the version from the module's Version.txt file, creates a zip archive
    of the module contents, and sets Azure DevOps pipeline variables for the zip path and version.

.PARAMETER ModulePath
    The path to the BcContainerHelper module directory.

.PARAMETER OutputDirectory
    The directory where the zip file will be created.

.OUTPUTS
    Creates a zip file named "BcContainerHelper-{version}.zip" and sets pipeline variables:
    - BCContainerHelperZipPath: Full path to the created zip file
    - BCContainerHelperVersion: Version number from Version.txt
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ModulePath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory
)

$errorActionPreference = "Stop"

$versionFile = Join-Path $ModulePath 'Version.txt'
$version = Get-Content -Path $versionFile

# Create a zip file of the module
if(-not (Test-Path -Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}
$zipPath = Join-Path $OutputDirectory "BcContainerHelper-$version.zip"

Write-Host "Zipping module from $ModulePath to $zipPath"
Compress-Archive -Path "$ModulePath" -DestinationPath $zipPath -Force

Write-Host "##vso[task.setvariable variable=BCContainerHelperZipPath;isreadonly=true]$zipPath"
Write-Host "##vso[task.setvariable variable=BCContainerHelperVersion;isreadonly=true]$version"
