<#
 .SYNOPSIS
  Copy App Files to the symbols folder in a CompilerFolder.
 .DESCRIPTION
  This is used for adding compiled bits to a compiler folder - kind of like installing the bits in a real container
  This way, the compile function can "download" symbols from the compiler folder.
 .PARAMETER compilerFolder
  The compiler folder, containing the symbols folder, in which to copy the app files to
 .PARAMETER appFiles
  A .app file, a .zip file or an array of .app files or .zip files to copy to the compiler folder
 .PARAMETER includeOnlyAppIds
  Only include these app ids
 .PARAMETER copyInstalledAppsToFolder
  Additionally copy the apps used to this folder
 .PARAMETER checkAlreadyInstalled
  If set, only copy apps that are not already present in the compiler folder
 .EXAMPLE
  Copy-AppFilesToCompilerFolder -compilerFolder $compilerFolder -appFiles $Parameters.appFile
#>
function Copy-AppFilesToCompilerFolder {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $compilerFolder,
        [Parameter(Mandatory=$true)]
        $appFiles,
        [string[]] $includeOnlyAppIds = @(),
        [string] $copyInstalledAppsToFolder = "",
        [switch] $checkAlreadyInstalled
    )

    Write-Host "Copy app files to compiler folder"
    $symbolsPath = Join-Path $compilerFolder 'symbols'
    $compilerFolderAppFiles = @(Get-ChildItem -Path (Join-Path $symbolsPath '*.app') | Select-Object -ExpandProperty FullName)
    $compilerFolderApps = GetAppInfo -AppFiles $compilerFolderAppFiles -compilerFolder $compilerFolder -cacheAppinfoPath (Join-Path $symbolsPath 'cache_AppInfo.json')
    if ($checkAlreadyInstalled) {
        $appFiles = @(Sort-AppFilesByDependencies -appFiles $appFiles -includeOnlyAppIds $includeOnlyAppIds -excludeInstalledApps $compilerFolderApps -WarningAction SilentlyContinue)
    }
    else {
        $appFiles = @(Sort-AppFilesByDependencies -appFiles $appFiles -includeOnlyAppIds $includeOnlyAppIds -WarningAction SilentlyContinue)
    }
    $appFiles | Where-Object { $_ } | ForEach-Object {
        $appFile = $_
        $appInfo = GetAppInfo -AppFiles $_ -compilerFolder $compilerFolder
        Write-Host "Copying $appFile to $symbolsPath"
        if ($copyInstalledAppsToFolder) {
            if (!(Test-Path -Path $copyInstalledAppsToFolder)) {
                New-Item -Path $copyInstalledAppsToFolder -ItemType Directory | Out-Null
            }
            Copy-Item -Path $appFile -Destination $copyInstalledAppsToFolder -force
        }
        $compilerFolderApp = $compilerFolderApps | Where-Object { $_.id -eq $appInfo.id }
        if ($compilerFolderApp) {
            Remove-Item -Path $compilerFolderApp.path -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$($compilerFolderApp.path).json" -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path $appFile -Destination $symbolsPath -force
    }
}
Export-ModuleMember -Function Copy-AppFilesToCompilerFolder
