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
    $compilerFolderAppFiles = @(Get-ChildItem -Path (Join-Path $symbolsPath '*.app'))
    $compilerFolderApps = GetAppInfo -AppFiles $compilerFolderAppFiles -compilerFolder $compilerFolder -cacheAppInfo
    if ($checkAlreadyInstalled) {
        $appFiles = @(Sort-AppFilesByDependencies -containerName $containerName -appFiles $appFiles -includeOnlyAppIds $includeOnlyAppIds -excludeInstalledApps $compilerFolderApps -WarningAction SilentlyContinue)
    }
    else {
        $appFiles = @(Sort-AppFilesByDependencies -containerName $containerName -appFiles $appFiles -includeOnlyAppIds $includeOnlyAppIds -WarningAction SilentlyContinue)
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
