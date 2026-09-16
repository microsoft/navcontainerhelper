param([string] $repoRoot = (Split-Path $PSScriptRoot -Parent))

# Load real functions without module initialization, telemetry startup or Docker discovery.
$functionNames = @(
    'GetAssemblyTargetFramework', 'GetCompatibleDotNetRuntime', 'ExpandDevelopmentToolsPackage',
    'CompareDevelopmentToolsPackageVersions', 'GetDevelopmentToolsPackageInfo',
    'ResolveBcCompilerSource', 'InstallBcCompilerSource', 'DetermineVsixFile',
    'New-BcCompilerFolder', 'GetAppInfo', 'CmdDo'
)
foreach ($file in @('HelperFunctions.ps1', 'CompilerFolderHandling\New-BcCompilerFolder.ps1')) {
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot $file), [ref]$null, [ref]$errors)
    if ($errors) { throw ($errors | Out-String) }
    foreach ($function in $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $functionNames
    }, $false)) {
        . ([scriptblock]::Create($function.Extent.Text))
    }
}
. (Join-Path $repoRoot 'NuGet\NuGetFeedClass.ps1')
