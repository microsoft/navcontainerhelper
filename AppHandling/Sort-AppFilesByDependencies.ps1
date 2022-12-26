<# 
 .Synopsis
  Sort an array of app files
 .Description
  Sort an array of app files with dependencies first, for compile and publish order
 .Parameter appFiles
  Array of app files
 .Parameter includeOnlyAppIds
  Array of AppIds. If specified, then include Only Apps in the specified AppFile array or archive which is contained in this Array and their dependencies
 .Parameter unknownDependencies
  If specified, this reference parameter will contain unresolved dependencies after sorting
 .Example
  $files = Sort-AppFilesByDependencies -appFiles @($app1, $app2)
#>
function Sort-AppFilesByDependencies {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $containerName = "",
        [Parameter(Mandatory=$false)]
        [string[]] $appFiles,
        [string[]] $includeOnlyAppIds = @(),
        $excludeInstalledApps = @(),
        [Parameter(Mandatory=$false)]
        [ref] $unknownDependencies
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if (!$appFiles) {
        return @()
    }

    $sharedFolder = ""
    if ($containerName) {
        $sharedFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\$([Guid]::NewGuid().ToString())"
        New-Item $sharedFolder -ItemType Directory | Out-Null
    }
    try {
        # Read all app.json objects, populate $apps
        $apps = $()
        $files = @{}
        $appFiles | ForEach-Object {
            $appFile = $_
            if ($containerName) {
                $destFile = Join-Path $sharedFolder ([System.IO.Path]::GetFileName($appFile))
                Copy-Item -Path $appFile -Destination $destFile
                $appJson = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($appFile)
                    Get-NavAppInfo -Path $appFile | ConvertTo-Json -Depth 99
                } -argumentList (Get-BcContainerPath -containerName $containerName -path $destFile) | ConvertFrom-Json
                #Remove-Item -Path $destFile
                $appJson | Add-Member -NotePropertyName 'Id' -NotePropertyValue $appJson.AppId.Value
                if ($appJson.Dependencies) {
                    $appJson.Dependencies | ForEach-Object { if ($_) { 
                        $_ | Add-Member -NotePropertyName 'Id' -NotePropertyValue $_.AppId
                        $_ | Add-Member -NotePropertyName 'Version' -NotePropertyValue $_.MinVersion.ToString()
                    } }
                }
            }
            else {
                $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
                try {
                    Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson 6> $null
                    $appJsonFile = Join-Path $tmpFolder "app.json"
                    $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
                }
                catch {
                    if ($_.exception.message -eq "You cannot extract a runtime package") {
                        throw "AppFile $appFile is a runtime package. You will have to specify a running container in containerName in order to analyze dependencies between runtime packages"
                    }
                    else {
                        throw "Unable to extract and analyze appFile $appFile"
                    }
                }
                finally {
                    Remove-Item $tmpFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            $key = "$($appJson.Id):$($appJson.Version)"
            if (-not $files.ContainsKey($key)) {
                $files += @{ "$($appJson.Id):$($appJson.Version)" = $appFile }
                $apps += @($appJson)
            }
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
            $dependentApp = $apps | Where-Object { $_.Id -eq $dependencyAppId } | Sort-Object -Property @{ "Expression" = "[System.Version]Version" }
            if ($dependentApp) {
                if ($dependentApp -is [Array]) {
                    Write-Host -ForegroundColor Yellow "AppFiles contains multiple versions of the app with AppId $dependencyAppId"
                    $dependentApp = $dependentApp | Select-Object -Last 1
                }
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
        
        function MarkSortedApps { Param($AppId)
            $script:sortedApps | Where-Object { $_.Id -eq $AppId } | ForEach-Object {
                $_.Included = $true
                if ($_.Dependencies) {
                    $_.Dependencies | ForEach-Object {
                        $dependency = $_
                        if ($dependency) {
                            $dependencyAppId = "$(if ($dependency.PSObject.Properties.name -eq 'AppId') { $dependency.AppId } else { $dependency.Id })"
                            MarkSortedApps -AppId $dependencyAppId
                        }
                    }
                }
            }
        }

        $apps | Where-Object { $_.Name -eq "Application" } | ForEach-Object { AddAnApp -anApp $_ }
        $apps | ForEach-Object { AddAnApp -AnApp $_ }
    
        if ($excludeInstalledApps) {
            $script:sortedApps = $script:sortedApps | ForEach-Object {
                $appName = [System.IO.Path]::GetFileName($files["$($_.id):$($_.version)"])
                $app = $_
                $installedApp = $excludeInstalledApps | Where-Object { $_.id -eq $app.id }
                if (!$installedApp) {
                    $app
                }
                elseif ([System.Version]$app.Version -eq $installedApp.Version ) {
                    Write-Host "$appName is already installed with the same version"
                }
                elseif ([System.Version]$app.Version -lt $installedApp.Version ) {
                    Write-Host "$appName is already installed with a newer version"
                }
                else {
                    $app
                }
            }
        }
        if ($includeOnlyAppIds) {
            $script:sortedApps | ForEach-Object { $_ | Add-Member -NotePropertyName 'Included' -NotePropertyValue $false }
            $includeOnlyAppIds | ForEach-Object { MarkSortedApps -AppId $_ }
            $script:sortedApps | Where-Object { $_.Included } | ForEach-Object {
                $files["$($_.id):$($_.version)"]
            }
        }
        else {
            $script:sortedApps | ForEach-Object {
                $files["$($_.id):$($_.version)"]
            }
        }
        if ($unknownDependencies) {
            $unknownDependencies.value = @($script:unresolvedDependencies | ForEach-Object { if ($_) { 
    			"$(if ($_.PSObject.Properties.name -eq 'AppId') { $_.AppId } else { $_.Id }):" + $("$($_.publisher)_$($_.name)_$($_.version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
    		} })
        }
    }
    finally {
        if ($sharedFolder) {
            Remove-Item $sharedFolder -Recurse -Force
        }
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Sort-AppFilesByDependencies
