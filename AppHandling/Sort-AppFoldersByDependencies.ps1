<# 
 .Synopsis
  Sort an array of app folders
 .Description
  Sort an array of app folders with dependencies first, for compile and publish order
 .Parameter appFolders
  Array of folders including an app.json
 .Parameter unknownDependencies
  If specified, this reference parameter will contain unresolved dependencies after sorting
 .Example
  $folders = Sort-AppFoldersByDependencies -appFolders @($folder1, $folder2)
#>
function Sort-AppFoldersByDependencies {
    Param(
        [Parameter(Mandatory=$true)]
        [string[]] $appFolders,
        [Parameter(Mandatory=$false)]
        [ref] $unknownDependencies
    )

    # Read all app.json objects, populate $apps
    $apps = $()
    $folders = @{}
    $appFolders | ForEach-Object {
        $appFolder = $_
        $appJsonFile = Join-Path $appFolder "app.json"
        if (-not (Test-Path -Path $appJsonFile)) {
            Write-Warning "$appFolder doesn't contain app.json"
        }
        else {
            $appJson = Get-Content -Path $appJsonFile | ConvertFrom-Json
            $folders += @{ "$($appJson.Id)" = $appFolder }
            $apps += @($appJson)
        }
    }
    
    # Populate SortedApps and UnresolvedDependencies
    $script:sortedApps = @()
    $script:unresolvedDependencies = $()

    function AddAnApp { Param($anApp) 
        $alreadyAdded = $script:sortedApps | Where-Object { $_.Id -eq $anApp.Id }
        if (-not ($alreadyAdded)) {
            AddDependencies -anApp $anApp
            $script:sortedApps += $anApp
        }
    }
    
    function AddDependency { Param($dependency)
        $dependentApp = $apps | Where-Object { $_.Id -eq $dependency.AppId }
        if ($dependentApp) {
            AddAnApp -AnApp $dependentApp
        }
        else {
            if (-not ($script:unresolvedDependencies | Where-Object { $_.appId -eq $dependency.AppId })) {
                Write-Host -ForegroundColor Red "Dependency $($dependency.appId):$($dependency.publisher.Replace('/',''))_$($dependency.name.Replace('/',''))_$($dependency.version)).app not found"
                $script:unresolvedDependencies += @($dependency)
            }
        }
    }
    
    function AddDependencies { Param($anApp)
        if (($anApp) -and ($anApp.Dependencies)) {
            $anApp.Dependencies | ForEach-Object { AddDependency -Dependency $_ }
        }
    }
    
    $apps | ForEach-Object { AddAnApp -AnApp $_ }

    $script:sortedApps | ForEach-Object { $folders[$_.id] }
    if ($unknownDependencies) {
        $unknownDependencies.value = @($script:unresolvedDependencies | ForEach-Object { if ($_) { "$($_.appId):$($_.publisher.Replace('/',''))_$($_.name.Replace('/',''))_$($_.version).app" } })
    }
}
Export-ModuleMember -Function Sort-AppFoldersByDependencies
