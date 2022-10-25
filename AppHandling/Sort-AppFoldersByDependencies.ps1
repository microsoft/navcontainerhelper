<# 
 .Synopsis
  Sort an array of app folders
 .Description
  Sort an array of app folders with dependencies first, for compile and publish order
 .Parameter appFolders
  Array of folders including an app.json
 .Parameter baseFolder
  If specified, all appFolders in the array are subFolders to this folder.
 .Parameter unknownDependencies
  If specified, this reference parameter will contain unresolved dependencies after sorting
 .Parameter knownApps
  If specified, this reference parameter will contain all known appids
 .Example
  $folders = Sort-AppFoldersByDependencies -appFolders @($folder1, $folder2)
#>
function Sort-AppFoldersByDependencies {
    Param(
        [Parameter(Mandatory=$false)]
        [string[]] $appFolders,
        [Parameter(Mandatory=$false)]
        [string] $baseFolder = "",
        [Parameter(Mandatory=$false)]
        [ref] $unknownDependencies,
        [Parameter(Mandatory=$false)]
        [ref] $knownApps
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if (!$appFolders) {
        return @()
    }

    if ($baseFolder) {
        $baseFolder = $baseFolder.TrimEnd('\')+'\'
    }

    # Read all app.json objects, populate $apps
    $apps = $()
    $folders = @{}
    $appFolders | ForEach-Object {
        $appFolder = "$baseFolder$_"
        $appJsonFile = Join-Path $appFolder "app.json"
        if (-not (Test-Path -Path $appJsonFile)) {
            Write-Warning "$appFolder doesn't contain app.json"
        }
        else {
            $appJson =[System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
            
            # replace id with appid
            if ($appJson.psobject.Members | Where-Object name -eq "dependencies") {
                if ($appJson.dependencies) {
                    $appJson.dependencies = @($appJson.dependencies | % {
                        $_ | ConvertTo-Json -Compress | Out-Host
                        if ($_.PSObject.Properties.Name -eq "id") {
                            $name = "$(if ($_.PSObject.Properties.Name -eq "name") { $_.Name })"
                            $publisher = "$(if ($_.PSObject.Properties.Name -eq "publisher") { $_.Publisher })"
                            New-Object psobject -Property ([ordered]@{ "appId" = $_.id; "publisher" = $publisher; "name" = $name; "version" = $_.version })
                        }
                        else {
                            $_
                        }
                    })
                }
            }
            else {
                $appJson | Add-Member -Name "dependencies" -Type NoteProperty -Value @()
            }
            if ($appJson.psobject.Members | Where-Object name -eq "application") {
                if ($appJson.Id -ne "63ca2fa4-4f03-4f2b-a480-172fef340d3f") {
                    $appJson.dependencies += @( New-Object psobject -Property ([ordered]@{ "appId" = "437dbf0e-84ff-417a-965d-ed2bb9650972"; "publisher" = "Microsoft"; "name" = "Base Application"; "version" = $appJson.application }) )
                    $appJson.dependencies += @( New-Object psobject -Property ([ordered]@{ "appId" = "63ca2fa4-4f03-4f2b-a480-172fef340d3f"; "publisher" = "Microsoft"; "name" = "System Application"; "version" = $appJson.application }) )
                }
            }

            $folders += @{ "$($appJson.Id):$($appJson.Version)" = $appFolder }
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
    
    $apps | Where-Object { $_.Name -eq "Application" } | ForEach-Object { AddAnApp -anApp $_ }
    $apps | ForEach-Object { AddAnApp -AnApp $_ }

    $script:sortedApps | ForEach-Object {
        ($folders["$($_.id):$($_.version)"]).SubString($baseFolder.Length)
    }
    if ($knownApps) {
        $knownApps.value += @($script:sortedApps | ForEach-Object {
            $_.Id
		})
    }
    if ($unknownDependencies) {
        $unknownDependencies.value += @($script:unresolvedDependencies | ForEach-Object { if ($_) { 
            "$(if ($_.PSObject.Properties.name -eq 'AppId') { $_.AppId } else { $_.Id }):" + $("$($_.publisher)_$($_.name)_$($_.version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
		} })
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
Export-ModuleMember -Function Sort-AppFoldersByDependencies
