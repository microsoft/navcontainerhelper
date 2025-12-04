param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @(),
    [string] $moduleName,
	[string[]] $moduleDependencies = @()
)

Set-StrictMode -Version 2.0

$verbosePreference = "SilentlyContinue"
$warningPreference = 'Continue'
$errorActionPreference = 'Stop'

if (!([environment]::Is64BitProcess)) {
    throw "ContainerHelper cannot run in Windows PowerShell (x86), need 64bit mode"
}

$isPsCore = $PSVersionTable.PSVersion -ge "6.0.0"
if ($isPsCore) {
    $byteEncodingParam = @{ "asByteStream" = $true }
    $allowUnencryptedAuthenticationParam = @{ "allowUnencryptedAuthentication" = $true }
}
else {
    $byteEncodingParam = @{ "Encoding" = "byte" }
    $allowUnencryptedAuthenticationParam = @{ }
    $isWindows = $true
    $isLinux = $false
    $IsMacOS = $false
}
$myUsername = (whoami)
$isInsideContainer = ($myUsername -eq "user manager\containeradministrator")
if ($isWindows) {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
else {
    $isAdministrator = ((id -u) -eq 0)
}

$BcContainerHelperVersion = (Get-Content (Join-Path $PSScriptRoot "Version.txt")).Trim()
$LatestGenericTagVersion = (Get-Content (Join-Path $PSScriptRoot "LatestGenericTagVersion.txt")).Trim()
if (!$silent) {
    Write-Host "$($moduleName.SubString(0,$moduleName.Length-5)) version $BcContainerHelperVersion"
}
$isInsider = $BcContainerHelperVersion -like "*-dev" -or $BcContainerHelperVersion -like "*-preview*"

$dotNetRuntimeVersionInstalled = [System.Version]::new(0,0,0)
if ($isWindows) {
    $dotNetSharedFolder = 'C:\Program Files\dotnet\shared'
    if (Test-Path $dotNetSharedFolder) {
        $netCoreAppFolder = Join-Path $dotNetSharedFolder 'Microsoft.NETCore.App'
        if (Test-Path $netCoreAppFolder) {
            $versions = Get-ChildItem $netCoreAppFolder | ForEach-Object { 
                try {
                    if (Test-Path (Join-Path $dotNetSharedFolder "Microsoft.AspNetCore.App/$($_.Name)")) {
                        [System.Version]$_.Name
                    }
                }
                catch {
                }
            }
            $dotNetRuntimeVersionInstalled = $versions | Where-Object { ($_.Major -ne 9) -and ($_.Major -ne 10) } | Sort-Object -Descending | Select-Object -First 1
        }
    }
}

$depVersion = "0.0"
if (!$isInsider) { 
    $depVersion = $BcContainerHelperVersion.split('-')[0]
}

$moduleDependencies | ForEach-Object {
    $module = Get-Module $_
    if ($module -ne $null -and $module.Version -lt [Version]$depVersion) {
        Write-Error "Module $_ is already loaded in version $($module.Version). This module requires version $depVersion. Please reinstall BC modules."
    }
    elseif ($module -eq $null) {
        if ($isInsider) {
            Import-Module (Join-Path $PSScriptRoot "$_.psm1") -DisableNameChecking -Global -ArgumentList $silent,$bcContainerHelperConfigFile
        }
        else {
            Import-Module $_ -MinimumVersion $depVersion -DisableNameChecking -Global -ArgumentList $silent,$bcContainerHelperConfigFile
        }
    }
}

