<# 
 .Synopsis
  Sort an array of app files
 .Description
  Sort an array of app files with dependencies first, for compile and publish order
 .Parameter appFiles
  Array of app files
 .Parameter unknownDependencies
  If specified, this reference parameter will contain unresolved dependencies after sorting
 .Example
  $files = Sort-AppFilesByDependencies -appFiles @($app1, $app2)
#>
function Sort-AppFilesByDependencies {
    Param(
        [Parameter(Mandatory=$true)]
        [string[]] $appFiles,
        [Parameter(Mandatory=$false)]
        [ref] $unknownDependencies
    )

    # Read all app.json objects, populate $apps
    $apps = $()
    $files = @{}
    $appFiles | ForEach-Object {
        $appFile = $_
        $tmpFolder = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
        try {
            Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson 6> $null
            $appJsonFile = Join-Path $tmpFolder "app.json"
            $appJson = Get-Content -Path $appJsonFile | ConvertFrom-Json
                
            $files += @{ "$($appJson.Id)" = $appFile }
            $apps += @($appJson)
        }
        catch {
            throw "Unable to extract and analyze appFile $appFile - might be a runtime package"
        }
        finally {
            Remove-Item $tmpFolder -Recurse -Force -ErrorAction SilentlyContinue
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
            if (-not ($script:unresolvedDependencies | Where-Object { $_ -and $_.AppId -eq $dependency.AppId })) {
                $appFileName = "$($dependency.publisher)_$($dependency.name)_$($dependency.version)).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
                Write-Warning "Dependency $($dependency.appId):$appFileName not found"
                $script:unresolvedDependencies += @($dependency)
            }
        }
    }
    
    function AddDependencies { Param($anApp)
        if ($anApp) {
            if ($anApp.psobject.Members | Where-Object name -eq "dependencies") {
                if ($anApp.Dependencies) {
                    $anApp.Dependencies | ForEach-Object { AddDependency -Dependency $_ }
                }
            }
        }
    }
    
    $apps | Where-Object { $_.Name -eq "Application" } | ForEach-Object { AddAnApp -anApp $_ }
    $apps | ForEach-Object { AddAnApp -AnApp $_ }

    $script:sortedApps | ForEach-Object {
        $files[$_.id]
    }
    if ($unknownDependencies) {
        $unknownDependencies.value = @($script:unresolvedDependencies | ForEach-Object { if ($_) { 
			"$($_.appId):" + $("$($_.publisher)_$($_.name)_$($_.version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
		} })
    }
}
Export-ModuleMember -Function Sort-AppFilesByDependencies
