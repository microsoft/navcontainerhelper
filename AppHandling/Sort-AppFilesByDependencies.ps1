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
        [Parameter(Mandatory=$false)]
        [string[]] $appFiles,
        [Parameter(Mandatory=$false)]
        [ref] $unknownDependencies
    )

    if (!$appFiles) {
        return @()
    }

    # Read all app.json objects, populate $apps
    $apps = $()
    $files = @{}
    $appFiles | ForEach-Object {
        $appFile = $_
        $tmpFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
        try {
            Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson 6> $null
            $appJsonFile = Join-Path $tmpFolder "app.json"
            $appJson = Get-Content -Path $appJsonFile | ConvertFrom-Json
        }
        catch {
            throw "Unable to extract and analyze appFile $appFile - might be a runtime package"
        }
        finally {
            Remove-Item $tmpFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        $files += @{ "$($appJson.Id):$($appJson.Version)" = $appFile }
        $apps += @($appJson)
    }
    
    # Populate SortedApps and UnresolvedDependencies
    $script:sortedApps = @()
    $script:unresolvedDependencies = $()

    function AddAnApp { Param($anApp) 
        $alreadyAdded = $script:sortedApps | Where-Object { $_.Id -eq $anApp.Id -and $_.Version -eq $anApp.Version }
        if (-not ($alreadyAdded)) {
            AddDependencies -anApp $anApp
            $script:sortedApps += $anApp
        }
    }
    
    function AddDependency { Param($dependency)
        $dependencyAppId = "$(if ($dependency.PSObject.Properties.name -eq 'AppId') { $dependency.AppId } else { $dependency.Id })"
        $dependentApp = $apps | Where-Object { $_.Id -eq $dependencyAppId }
        if ($dependentApp) {
            AddAnApp -AnApp $dependentApp
        }
        else {
            if (-not ($script:unresolvedDependencies | Where-Object { $_ } | Where-Object { "$(if ($_.PSObject.Properties.name -eq 'AppId') { $_.AppId } else { $_.Id })" -eq $dependencyAppId })) {
                $appFileName = "$($dependency.publisher)_$($dependency.name)_$($dependency.version)).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
                if ($dependencyAppid -ne '63ca2fa4-4f03-4f2b-a480-172fef340d3f' -and $dependencyAppId -ne '437dbf0e-84ff-417a-965d-ed2bb9650972') {
                    Write-Warning "Dependency $($dependencyAppId):$appFileName not found"
                }
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
        $files["$($_.id):$($_.version)"]
    }
    if ($unknownDependencies) {
        $unknownDependencies.value = @($script:unresolvedDependencies | ForEach-Object { if ($_) { 
			"$(if ($_.PSObject.Properties.name -eq 'AppId') { $_.AppId } else { $_.Id }):" + $("$($_.publisher)_$($_.name)_$($_.version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
		} })
    }
}
Export-ModuleMember -Function Sort-AppFilesByDependencies
