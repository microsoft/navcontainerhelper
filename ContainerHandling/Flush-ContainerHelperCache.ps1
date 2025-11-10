<# 
 .Synopsis
  Flush Caches used in ContainerHelper
 .Description
  Extract all files from a Container Image necessary to start a generic container with these files
 .Parameter cache
  Specify which cache you want to flush (default is all)
  - calSourceCache is the C/AL Source Cache
  - alSourceCache is the AL Source Cache
  - filesCache is the files extracted from other images
  - applicationCache are the test applications runtime cache (15.x containers)
  - bakFolderCache are version specific backup sets
  - bcartifacts are artifacts downloaded for spinning up containers
  - bcnuget are nuget packages downloaded to nuget cache
  - sandboxartifacts are artifacts downloaded for spinning up containers
  - images are images built on artifacts using New-BcImage or New-BcContainer
  - compilerFolders are folders used for Dockerless builds
  - exitedContainers are containers which have been stopped
  - all is all of the above (except for exited Containers)
 .Parameter keepDays
  When specifying a value in keepDays, the function will try to keep cached information, which has been used during the last keepDays days. Default is 0 - to flush all cache.
 .Example
  Flush-ContainerHelperCache -cache calSourceCache
#>
function Flush-ContainerHelperCache {
    [CmdletBinding()]
    Param (
        [string] $cache = 'all',
        [int] $keepDays = 0
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $flushMutexName = "FlushContainerHelperCache"
    $flushMutex = New-Object System.Threading.Mutex($false, $flushMutexName)
    try {
        try {
            if (!$flushMutex.WaitOne(1000)) {
                Write-Host "Waiting for other process flushing cache"
                $flushMutex.WaitOne() | Out-Null
                Write-Host "Other process completed flushing"
            }
        }
        catch [System.Threading.AbandonedMutexException] {
           Write-Host "Other process terminated abnormally"
        }

        $artifactsCacheFolder = $bcContainerHelperConfig.bcartifactsCacheFolder
        $caches = $cache.ToLowerInvariant().Split(',')
    
        if ($caches.Contains('exitedcontainers')) {
            docker container ls --format "{{.ID}}:{{.Names}}" --no-trunc -a --filter "status=exited" | ForEach-Object {
                $containerID = $_.Split(':')[0]
                $containerName = $_.Split(':')[1]
                $inspect = docker inspect $containerID | ConvertFrom-Json
                try {
                    if ($inspect.state.FinishedAt -is [datetime]) {
                        $finishedAt = $inspect.state.FinishedAt
                    }
                    else {
                        $finishedAt = [DateTime]::Parse($inspect.state.FinishedAt)
                    }
                    $exitedDaysAgo = [DateTime]::Now.Subtract($finishedAt).Days
                    if ($exitedDaysAgo -ge $keepDays) {
                        if (($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -ne 0 -and $inspect.Config.Labels.maintainer -eq "Dynamics SMB")) {
                            if ($caches.Contains('algocontainersonly')) {
                                if ($inspect.Config.Labels.psobject.Properties.Match('creator').Count -ne 0 -and $inspect.Config.Labels.creator -eq "AL-Go") {
                                    Write-Host "Removing AL-Go container $containerName"
                                    docker rm $containerID -f
                                } 
                                else {
                                    Write-Host "Container $containerName (exited $exitedDaysAgo day$(if($exitedDaysAgo -ne 1){'s'}) ago) is recognized as a Business Central Container, but was not created by AL-Go - not removing"
                                }
                            } 
                            else {
                                Write-Host "Removing container $containerName"
                                docker rm $containerID -f
                            }   
                        }
                        else {
                            Write-Host "Container $containerName (exited $exitedDaysAgo day$(if($exitedDaysAgo -ne 1){'s'}) ago) is not recognized as a Business Central Container - not removing"
                        }
                    }
                    else {
                        Write-Host "Keeping container $containerName (exited $exitedDaysAgo day$(if($exitedDaysAgo -ne 1){'s'}) ago) - removing after $keepDays day$(if($keepDays -ne 1){'s'})"
                    }
                }
                catch {
                    # ignore any errors
                }
            }
        }

        $folders = @()
        if ($caches.Contains('all') -or $caches.Contains('calSourceCache')) {
            $folders += @("extensions\original-*-??","extensions\original-*-??-newsyntax")
        }
    
        if ($caches.Contains('all') -or $caches.Contains('filesCache')) {
            $folders += @("*-??-files")
        }
    
        if ($caches.Contains('all') -or $caches.Contains('bcartifacts') -or $caches.Contains('sandboxartifacts')) {
            $subfolder = "*"
            if (!($caches.Contains('all') -or $caches.Contains('bcartifacts'))) {
                $subfolder = "sandbox"
            }
            if (Test-Path $artifactsCacheFolder) {
                if ($keepDays) {
                    $removeBefore = [DateTime]::Now.Subtract([timespan]::FromDays($keepDays))
                    Get-ChildItem -Path $artifactsCacheFolder | Where-Object { $_.PSIsContainer -and $_.Name -like $subfolder } | ForEach-Object {
                        $level1 = $_.FullName
                        Get-ChildItem -Path $level1 | ?{ $_.PSIsContainer } | ForEach-Object {
                            $level2 = $_.FullName
                            Get-ChildItem -Path $level2 | ?{ $_.PSIsContainer } | ForEach-Object {
                                $level3 = $_.FullName
                                $lastUsedFileName = Join-Path $level3 "LastUsed"
                                if (Test-Path $lastUsedFileName) {
                                    $lastUsedFile = Get-Item $lastUsedFileName
                                    if ($lastUsedFile.LastWriteTime -lt $removeBefore) {
                                        Write-Host "Removing $level3"
                                        Remove-Item $level3 -Recurse -Force
                                    }
                                }
                            }
                            if (-not (Get-ChildItem -Path $level2)) {
                                Remove-Item $level2 -Force
                            }
                        }
                        if (-not (Get-ChildItem -Path $level1)) {
                            Remove-Item $level1 -Force
                        }
                    }
                }
                else {
                    Get-ChildItem -Path $artifactsCacheFolder | ?{ $_.PSIsContainer -and $_.Name -like $subfolder } | ForEach-Object {
                        Write-Host "Removing Cache $($_.FullName)"
                        [System.IO.Directory]::Delete($_.FullName, $true)
                    }
                }
            }
        }
    
        if ($caches.Contains('all') -or $caches.Contains('alSourceCache')) {
            $folders += @("extensions\original-*-??-al")
        }
    
        if ($caches.Contains('all') -or $caches.Contains('applicationCache')) {
            $folders += @("extensions\applications-*-??","extensions\sandbox-applications-*-??","extensions\onprem-applications-*-??")
        }

        if ($caches.Contains('all') -or $caches.Contains('compilerFolders')) {
            # Remove CompilerFolders created 24h ago or earlier
            Push-Location -path $bcContainerHelperConfig.hostHelperFolder
            $compilerPath = Join-Path $bcContainerHelperConfig.hostHelperFolder 'compiler'
            if (Test-Path $compilerPath) {
                $removeBefore = [DateTime]::UtcNow.AddDays(-$keepDays)
                $folders += @(Get-ChildItem -Path $compilerPath | Where-Object { $_.PSIsContainer } | Where-Object { $_.CreationTimeUtc -lt $removeBefore } | ForEach-Object { Resolve-Path $_.FullName -Relative })
            }
            Pop-Location
        }

        if ($caches.Contains('all') -or $caches.Contains('bakFolderCache')) {
            $folders += @("sandbox-*-bakfolders","onprem-*-bakfolders")
        }
    
        $folders | ForEach-Object {
            $folder = Join-Path $bcContainerHelperConfig.hostHelperFolder $_
            Get-Item $folder -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object {
                Write-Host "Removing Cache $($_.FullName)"
                [System.IO.Directory]::Delete($_.FullName, $true)
            }
        }
    
        if (($caches.Contains('all') -or $caches.Contains('bcnuget')) -and ($bcContainerHelperConfig.BcNuGetCacheFolder) -and (Test-Path $bcContainerHelperConfig.BcNuGetCacheFolder)) {
            Get-ChildItem -Path $bcContainerHelperConfig.BcNuGetCacheFolder | Where-Object { $_.PSIsContainer } | ForEach-Object {
                Get-ChildItem -Path $_.FullName | ForEach-Object {
                    $lastWrite = $_.LastWriteTime
                    if ($keepDays -eq 0 -or $lastWrite -lt (Get-Date).AddDays(-$keepDays)) {
                        Write-Host "Remove $($_.FullName.SubString($bcContainerHelperConfig.BcNuGetCacheFolder.Length+1))"
                        Remove-Item -Path $_.FullName -Recurse -Force
                    }
                }
            }
        }

        if ($caches.Contains('all') -or $caches.Contains('images')) {
            $bestGenericImageName = Get-BestGenericImageName
            $allImages = @(docker images --no-trunc --format "{{.Repository}}:{{.Tag}}|{{.ID}}")
            $bestGenericImage = $allImages | Where-Object { $_.Split('|')[0] -eq $bestGenericImageName }
            if ($bestGenericImage) {
                $bestGenericImageId = $bestGenericImage.Split('|')[1]
                $bestGenericImageInspect = docker inspect $bestGenericImageID | ConvertFrom-Json
            }
            $usedImages = docker ps -a --no-trunc --format '{{.Image}}'
            $allImages | ForEach-Object {
                $imageName = $_.Split('|')[0]
                if ($usedImages -notcontains $imageName) {
                    $imageID = $_.Split('|')[1]
                    $inspect = docker inspect $imageID | ConvertFrom-Json
                    $artifactUrl = $inspect.config.Env | Where-Object { $_ -like "artifactUrl=*" }
                    if ($artifactUrl) {
                        $artifactUrl = $artifactUrl.Split('?')[0]
                        "artifactUrl=https://bcartifacts*.net/",
                        "artifactUrl=https://bcinsider*.net/",
                        "artifactUrl=https://bcprivate*.net/",
                        "artifactUrl=https://bcpublicpreview*.net/" | ForEach-Object {
                            if ($artifactUrl -like "$($_)*") {
                                $cacheFolder = Join-Path $artifactsCacheFolder $artifactUrl.Substring($artifactUrl.IndexOf('/',$_.Length)+1)
                                if (-not (Test-Path $cacheFolder)) {
                                    Write-Host "$imageName was built on artifacts which was removed from the cache, removing image"
                                    if (-not (DockerDo -command rmi -parameters @("--force") -imageName $imageID -ErrorAction SilentlyContinue)) {
                                        Write-Host "WARNING: Unable to remove image"
                                    }
                                }
                            }
                        }
                    }
                    elseif ($bestGenericImage) {
                        try {
                            if ($inspect.config.Labels.maintainer -eq "Dynamics SMB" -and 
                                $inspect.Config.Labels.tag -ne "" -and 
                                $inspect.Config.Labels.osversion -ne $bestGenericImageInspect.Config.Labels.osversion) {
                                Write-Host "$imageName is a generic image for an old version of your OS, removing image"
                                if (-not (DockerDo -command rmi -parameters @("--force") -imageName $imageID -ErrorAction SilentlyContinue)) {
                                    Write-Host "WARNING: Unable to remove image"
                                }
                            }
                        } catch {}
                    }
                }
            }
            if ($keepDays -eq 0) {
                Write-Host "Running Docker image prune"
                docker image prune -f > $null
            }
            else {
                $h = 24*$keepDays
                Write-Host "Running Docker image prune --filter ""until=$($h)h"""
                docker image prune -f --filter "until=$($h)h" > $null
            }
            Write-Host "Completed"
        }
    }
    finally {
        $flushMutex.ReleaseMutex()
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
Export-ModuleMember -Function Flush-ContainerHelperCache
