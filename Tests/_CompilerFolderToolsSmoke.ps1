#requires -Version 7.0
<#
.SYNOPSIS
Opt-in compiler smoke check using a local Development.Tools package and a platform assembly.
.DESCRIPTION
Does not download packages or authenticate to feeds. Compiles a small app with CodeCop and
reads its metadata through the DLL-only altool path in a folder containing spaces.
Deletes only its own temporary compiler and project.
.EXAMPLE
.\Tests\_CompilerFolderToolsSmoke.ps1 -packageFile C:\temp\tools.nupkg -platformAssembly C:\temp\Microsoft.Dynamics.Nav.Ncl.dll
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $packageFile,
    [Parameter(Mandatory = $true)]
    [string] $platformAssembly,
    [string] $alRuntime = '15.0'
)

$ErrorActionPreference = 'Stop'
$isPsCore = $true
. (Join-Path $PSScriptRoot '_LoadCompilerFolderFunctions.ps1')
function Expand-7zipArchive {
    [CmdletBinding()]
    param($Path, $DestinationPath)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) "Compiler smoke $([Guid]::NewGuid())"
try {
    $compilerFolder = Join-Path $scratch 'Compiler Folder'
    InstallBcCompilerSource -source @{ Kind = 'ArtifactTools'; Path = $packageFile; PlatformAssembly = $platformAssembly } -destinationPath (Join-Path $compilerFolder 'compiler')
    $bin = Join-Path $compilerFolder 'compiler\extension\bin'
    $project = Join-Path $scratch 'AL Project'
    New-Item $project -ItemType Directory -Force | Out-Null
    @{ id = [Guid]::NewGuid().ToString(); name = 'CompilerSmoke'; publisher = 'Test'; version = '1.0.0.0'; runtime = $alRuntime; target = 'Cloud' } |
        ConvertTo-Json | Set-Content (Join-Path $project 'app.json')
    @'
namespace CompilerSmoke;
codeunit 50100 Smoke
{
    procedure Value(): Integer
    begin
        exit(42);
    end;
}
'@ | Set-Content (Join-Path $project 'Smoke.Codeunit.al')
    $output = Join-Path $scratch 'Smoke.app'
    & dotnet (Join-Path $bin 'alc.dll') "/project:$project" "/out:$output" "/analyzer:$(Join-Path $bin 'Microsoft.Dynamics.Nav.CodeCop.dll')"
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $output)) { throw 'Compiler smoke compilation failed.' }
    foreach ($appHost in @('altool.exe', 'altool')) {
        $path = Join-Path $bin $appHost
        if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
    }
    $info = @(GetAppInfo -appFiles @($output) -compilerFolder $compilerFolder)
    if ($info.Count -ne 1 -or $info[0].Name -ne 'CompilerSmoke') { throw 'Compiler smoke metadata check failed.' }
    Write-Host 'Compiler, CodeCop and DLL-only metadata checks succeeded.'
}
finally {
    if (Test-Path $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
