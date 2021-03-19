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
  - sandboxartifacts are artifacts downloaded for spinning up containers
  - images are images built on artifacts using New-BcImage or New-BcContainer
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

    $caches = $cache.ToLowerInvariant().Split(',')

    $folders = @()
    if ($caches.Contains('all') -or $caches.Contains('calSourceCache')) {
        $folders += @("extensions\original-*-??","extensions\original-*-??-newsyntax")
    }

    if ($caches.Contains('all') -or $caches.Contains('filesCache')) {
        $folders += @("*-??-files")
    }

    if ($caches.Contains('all') -or $caches.Contains('bcartifacts') -or $caches.Contains('sandboxartifacts')) {
        $bcartifactsCacheFolder = (Get-ContainerHelperConfig).bcartifactsCacheFolder
        $subfolder = "*"
        if (!($caches.Contains('all') -or $caches.Contains('bcartifacts'))) {
            $subfolder = "sandbox"
        }
        if (Test-Path $bcartifactsCacheFolder) {
            if ($keepDays) {
                $removeBefore = [DateTime]::Now.Subtract([timespan]::FromDays($keepDays))
                Get-ChildItem -Path $bcartifactsCacheFolder | ?{ $_.PSIsContainer -and $_.Name -like $subfolder } | ForEach-Object {
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
                Get-ChildItem -Path $bcartifactsCacheFolder | ?{ $_.PSIsContainer -and $_.Name -like $subfolder } | ForEach-Object {
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

    if ($caches.Contains('all') -or $caches.Contains('bakFolderCache')) {
        $folders += @("sandbox-*-bakfolders","onprem-*-bakfolders")
    }

    $folders | ForEach-Object {
        $folder = Join-Path $hostHelperFolder $_
        Get-Item $folder -ErrorAction SilentlyContinue | ?{ $_.PSIsContainer } | ForEach-Object {
            Write-Host "Removing Cache $($_.FullName)"
            [System.IO.Directory]::Delete($_.FullName, $true)
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
        $allImages | ForEach-Object {
            $imageName = $_.Split('|')[0]
            $imageID = $_.Split('|')[1]
            $inspect = docker inspect $imageID | ConvertFrom-Json
            $artifactUrl = $inspect.config.Env | Where-Object { $_ -like "artifactUrl=*" }
            if ($artifactUrl) {
                $artifactUrl = $artifactUrl.Split('?')[0]
                "artifactUrl=https://bcartifacts.azureedge.net/",
                "artifactUrl=https://bcinsider.azureedge.net/",
                "artifactUrl=https://bcprivate.azureedge.net/",
                "artifactUrl=https://bcpublicpreview.azureedge.net/" | % {
                    if ($artifactUrl -like "$($_)*") {
                        $cacheFolder = Join-Path $bcContainerHelperConfig.bcartifactsCacheFolder $artifactUrl.SubString($_.Length)
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
        Write-Host "Running Docker image prune"
        docker image prune -f > $null
        Write-Host "Completed"
    }
}
Export-ModuleMember -Function Flush-ContainerHelperCache
