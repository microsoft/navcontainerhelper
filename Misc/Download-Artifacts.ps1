<#
 .Synopsis
  Download Artifacts
 .Description
  Download artifacts from artifacts storage
 .Parameter artifactUrl
  Url for application artifact to use.
 .Parameter includePlatform
  Add this switch to include the platform artifact in the download
 .Parameter force
  Add this switch to force download artifacts even though they already exists
 .Parameter forceRedirection
  Add this switch to force download redirection artifacts even though they already exists
 .Parameter basePath
  Load the artifacts into a file structure below this path. (default is c:\bcartifacts.cache)
 .Parameter timeout
  Timeout in seconds for each file download.
 .Example
  $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
  $appArtifactPath = $artifactPaths[0]
  $platformArtifactPath = $artifactPaths[1]
 .Example
  $appArtifactPath = Download-Artifacts -artifactUrl $artifactUrl
#>
function Download-Artifacts {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $artifactUrl,
        [switch] $includePlatform,
        [switch] $force,
        [switch] $forceRedirection,
        [string] $basePath = "",
        [int]    $timeout = 300
    )

    if ($basePath -eq "") {
        $basePath = (Get-ContainerHelperConfig).bcartifactsCacheFolder
    }

    if (-not (Test-Path $basePath)) {
        New-Item $basePath -ItemType Directory | Out-Null
    }

    $appMutexName = "dl-$($artifactUrl.Split('?')[0])"
    $appMutex = New-Object System.Threading.Mutex($false, $appMutexName)
    try {
        try {
            if (!$appMutex.WaitOne(1000)) {
                Write-Host "Waiting for other process downloading application artifact '$($artifactUrl.Split('?')[0])'"
                $appMutex.WaitOne() | Out-Null
                Write-Host "Other process completed download"
            }
        }
        catch [System.Threading.AbandonedMutexException] {
           Write-Host "Other process terminated abnormally"
        }
        do {
            $redir = $false
            $appUri = [Uri]::new($artifactUrl)
    
            $appArtifactPath = Join-Path $basePath $appUri.AbsolutePath
            $exists = Test-Path $appArtifactPath
            if ($exists -and $force) {
                Remove-Item $appArtifactPath -Recurse -Force
                $exists = $false
            }
            if ($exists -and $forceRedirection) {
                $appManifestPath = Join-Path $appArtifactPath "manifest.json"
                $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
                if ($appManifest.PSObject.Properties.name -eq "applicationUrl") {
                    # redirect artifacts are always downloaded
                    Remove-Item $appArtifactPath -Recurse -Force
                    $exists = $false
                }
            }
            if (-not $exists) {
                Write-Host "Downloading application artifact $($appUri.AbsolutePath)"
                $appZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
                TestSasToken -sasToken $artifactUrl
                Download-File -sourceUrl $artifactUrl -destinationFile $appZip -timeout $timeout
                Write-Host "Unpacking application artifact to tmp folder " -NoNewline
                $tmpFolder = Join-Path ([System.IO.Path]::GetDirectoryName($appArtifactPath)) ([System.IO.Path]::GetRandomFileName())
                try {
                    Expand-7zipArchive -Path $appZip -DestinationPath $tmpFolder
                    while (!(Test-Path "$appArtifactPath")) {
                        try {
                            Rename-Item -Path "$tmpFolder" -NewName ([System.IO.Path]::GetFileName($appArtifactPath)) -Force
                        }
                        catch {
                            Write-Host "Could not rename '$tmpFolder' retrying in 5 seconds."
                            Start-Sleep -Seconds 5
                            Write-Host "Retrying..."
                        }
                    }
                }
                finally {
                    Remove-Item -path $appZip -force
                    if (Test-Path $tmpFolder) {
                        Remove-Item $tmpFolder -Recurse -Force
                    }
                }
            }
            try { [System.IO.File]::WriteAllText((Join-Path $appArtifactPath 'lastused'), "$([datetime]::UtcNow.Ticks)") } catch {}
    
            $appManifestPath = Join-Path $appArtifactPath "manifest.json"
            $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
    
            if ($appManifest.PSObject.Properties.name -eq "applicationUrl") {
                $redir = $true
                $artifactUrl = $appManifest.ApplicationUrl
                if ($artifactUrl -notlike 'https://*') {
                    $artifactUrl = "https://$($appUri.Host)/$artifactUrl$($appUri.Query)"
                }
            }
    
        } while ($redir)
    
        $appArtifactPath
    
        if ($includePlatform) {
            if ($appManifest.PSObject.Properties.name -eq "platformUrl") {
                $platformUrl = $appManifest.platformUrl
            }
            else {
                $platformUrl = "$($appUri.AbsolutePath.Substring(0,$appUri.AbsolutePath.LastIndexOf('/')))/platform".TrimStart('/')
            }
        
            if ($platformUrl -notlike 'https://*') {
                $platformUrl = "https://$($appUri.Host.TrimEnd('/'))/$platformUrl$($appUri.Query)"
            }
            $platformUri = [Uri]::new($platformUrl)
    
            $PlatformMutexName = "dl-$($platformUrl.Split('?')[0])"
            $PlatformMutex = New-Object System.Threading.Mutex($false, $PlatformMutexName)
            try {
                try {
                    if (!$PlatformMutex.WaitOne(1000)) {
                        Write-Host "Waiting for other process downloading platform artifact '$($platformUrl.Split('?')[0])'"
                        $PlatformMutex.WaitOne() | Out-Null
                        Write-Host "Other process completed download"
                    }
                }
                catch [System.Threading.AbandonedMutexException] {
                   Write-Host "Other process terminated abnormally"
                }
    
                $platformArtifactPath = Join-Path $basePath $platformUri.AbsolutePath
                $exists = Test-Path $platformArtifactPath
                if ($exists -and $force) {
                    Remove-Item $platformArtifactPath -Recurse -Force
                    $exists = $false
                }
                if (-not $exists) {
                    Write-Host "Downloading platform artifact $($platformUri.AbsolutePath)"
                    $platformZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
                    TestSasToken -sasToken $artifactUrl
                    Download-File -sourceUrl $platformUrl -destinationFile $platformZip -timeout $timeout
                    Write-Host "Unpacking platform artifact to tmp folder " -NoNewline
                    $tmpFolder = Join-Path ([System.IO.Path]::GetDirectoryName($platformArtifactPath)) ([System.IO.Path]::GetRandomFileName())
                    try {
                        Expand-7zipArchive -Path $platformZip -DestinationPath $tmpFolder
                        $downloadprereqs = $false
                        while (!(Test-Path "$platformArtifactPath")) {
                            try {
                                Rename-Item -Path "$tmpFolder" -NewName ([System.IO.Path]::GetFileName($platformArtifactPath)) -Force
                                $downloadprereqs = $true
                            }
                            catch {
                                Write-Host "Could not rename '$tmpFolder' retrying in 5 seconds."
                                Start-Sleep -Seconds 5
                                Write-Host "Retrying..."
                            }

                            if ($downloadprereqs) {
                                $prerequisiteComponentsFile = Join-Path $platformArtifactPath "Prerequisite Components.json"
                                if (Test-Path $prerequisiteComponentsFile) {
                                    $prerequisiteComponents = Get-Content $prerequisiteComponentsFile | ConvertFrom-Json
                                    Write-Host "Downloading Prerequisite Components"
                                    $prerequisiteComponents.PSObject.Properties | % {
                                        $path = Join-Path $platformArtifactPath $_.Name
                                        if (-not (Test-Path $path)) {
                                            $dirName = [System.IO.Path]::GetDirectoryName($path)
                                            $filename = [System.IO.Path]::GetFileName($path)
                                            if (-not (Test-Path $dirName)) {
                                                New-Item -Path $dirName -ItemType Directory | Out-Null
                                            }
                                            $url = $_.Value
                                            Download-File -sourceUrl $url -destinationFile $path -timeout $timeout
                                        }
                                    }
                                    $dotnetCoreFolder = Join-Path $platformArtifactPath "Prerequisite Components\DotNetCore"
                                    if (!(Test-Path $dotnetCoreFolder)) {
                                        New-Item $dotnetCoreFolder -ItemType Directory | Out-Null
                                        Download-File -sourceUrl "https://go.microsoft.com/fwlink/?LinkID=844461" -destinationFile (Join-Path $dotnetCoreFolder "DotNetCore.1.0.4_1.1.1-WindowsHosting.exe") -timeout $timeout
                                    }
                                }
                            }
                        }
                    }
                    finally {
                        Remove-Item -path $platformZip -force
                        if (Test-Path $tmpFolder) {
                            Remove-Item $tmpFolder -Recurse -Force
                        }
                    }
        
                }
                try { [System.IO.File]::WriteAllText((Join-Path $platformArtifactPath 'lastused'), "$([datetime]::UtcNow.Ticks)") } catch {}
                $platformArtifactPath
            }
            finally {
                $platformMutex.ReleaseMutex()
            }
        }
    }
    finally {
        $appMutex.ReleaseMutex()
    }
}
Export-ModuleMember -Function Download-Artifacts
