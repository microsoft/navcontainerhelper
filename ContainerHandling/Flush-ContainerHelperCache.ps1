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
  - bcartifacts are artifacts downloaded for spinning up containers.
 .Parameter keepDays
  When specifying a value in keepDays, the function will try to keep cached information, which has been used during the last keepDays days. Default is 0 - to flush all cache.
 .Example
  Flush-ContainerHelperCache -cache calSourceCache
#>
function Flush-ContainerHelperCache {
    [CmdletBinding()]
    Param (
        [ValidateSet('all','calSourceCache','alSourceCache','applicationCache','bakFolderCache','filesCache','bcartifacts')]
        [string] $cache = 'all',
        [int] $keepDays = 0
    )

    $folders = @()
    if ($cache -eq 'all' -or $cache -eq 'calSourceCache') {
        $folders += @("extensions\original-*-??","extensions\original-*-??-newsyntax")
    }

    if ($cache -eq 'all' -or $cache -eq 'filesCache') {
        $folders += @("*-??-files")
    }

    if ($cache -eq 'all' -or $cache -eq 'bcartifacts') {
        $bcartifactsCacheFolder = (Get-ContainerHelperConfig).bcartifactsCacheFolder
        if (Test-Path $bcartifactsCacheFolder) {
            if ($keepDays) {
                $removeBefore = [DateTime]::Now.Subtract([timespan]::FromDays($keepDays))
                Get-ChildItem -Path $bcartifactsCacheFolder | ?{ $_.PSIsContainer } | ForEach-Object {
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
                Get-ChildItem -Path $bcartifactsCacheFolder | ?{ $_.PSIsContainer } | ForEach-Object {
                    Write-Host "Removing Cache $($_.FullName)"
                    [System.IO.Directory]::Delete($_.FullName, $true)
                }
            }
        }
    }

    if ($cache -eq 'all' -or $cache -eq 'alSourceCache') {
        $folders += @("extensions\original-*-??-al")
    }

    if ($cache -eq 'all' -or $cache -eq 'applicationCache') {
        $folders += @("extensions\applications-*-??","extensions\sandbox-applications-*-??","extensions\onprem-applications-*-??")
    }

    if ($cache -eq 'all' -or $cache -eq 'bakFolderCache') {
        $folders += @("sandbox-*-bakfolders","onprem-*-bakfolders")
    }

    $folders | ForEach-Object {
        $folder = Join-Path $hostHelperFolder $_
        Get-Item $folder -ErrorAction SilentlyContinue | ?{ $_.PSIsContainer } | ForEach-Object {
            Write-Host "Removing Cache $($_.FullName)"
            [System.IO.Directory]::Delete($_.FullName, $true)
        }
    }
}
Export-ModuleMember -Function Flush-ContainerHelperCache
