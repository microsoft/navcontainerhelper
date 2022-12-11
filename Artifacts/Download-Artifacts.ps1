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

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @("artifactUrl","includePlatform")
try {

    if ($basePath -eq "") {
        $basePath = $bcContainerHelperConfig.bcartifactsCacheFolder
    }

    if (-not (Test-Path $basePath)) {
        New-Item $basePath -ItemType Directory | Out-Null
    }

    $appMutexName = "dl-$($artifactUrl.Split('?')[0].Substring(8).Replace('/','_'))"
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
                TestSasToken -sasToken $artifactUrl
                $retry = $false
                do {
                    Write-Host $artifactUrl
                    $appZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
                    Download-File -sourceUrl $artifactUrl -destinationFile $appZip -timeout $timeout
                    Write-Host "Unpacking application artifact to tmp folder " -NoNewline
                    $tmpFolder = Join-Path ([System.IO.Path]::GetDirectoryName($appArtifactPath)) ([System.IO.Path]::GetRandomFileName())
                    try {
                        Expand-7zipArchive -Path $appZip -DestinationPath $tmpFolder -use7zipIfAvailable:(!$retry)
                        $retry = $false
                    }
                    catch {
                        Remove-Item -path $appZip -force
                        if (Test-Path $tmpFolder) {
                            Remove-Item $tmpFolder -Recurse -Force
                        }
                        if ($retry) {
                            throw "Error trying to unpack artifacts, downloaded package is corrupt"
                        }
                        else {
                            if ($artifactUrl -like "https://bcartifacts.azureedge.net/*" -or $artifactUrl -like "https://bcinsider.azureedge.net/*" -or $artifactUrl -like "https://bcprivate.azureedge.net/*" -or $artifactUrl -like "https://bcpublicpreview.azureedge.net/*") {
                                Write-Host "Error unpacking artifact downloaded from CDN, retrying download from direct download URL"
                                $idx = $artifactUrl.IndexOf('.azureedge.net/',[System.StringComparison]::InvariantCultureIgnoreCase)
                                $artifactUrl = $artifactUrl.Substring(0,$idx) + '.blob.core.windows.net' + $artifactUrl.Substring($idx + 14)
                                $retry = $true
                            }
                        }
                    }
                } while($retry)
                try {
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
                    if (Test-Path $appZip) {
                        Remove-Item -path $appZip -force
                    }
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
                    TestSasToken -sasToken $platformUrl
                    $retry = $false
                    do {
                        Write-Host $platformUrl
                        $platformZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
                        Download-File -sourceUrl $platformUrl -destinationFile $platformZip -timeout $timeout
                        Write-Host "Unpacking platform artifact to tmp folder " -NoNewline
                        $tmpFolder = Join-Path ([System.IO.Path]::GetDirectoryName($platformArtifactPath)) ([System.IO.Path]::GetRandomFileName())
                        try {
                            Expand-7zipArchive -Path $platformZip -DestinationPath $tmpFolder -use7zipIfAvailable:(!$retry)
                            $retry = $false
                        }
                        catch {
                            Remove-Item -path $platformZip -force
                            if (Test-Path $tmpFolder) {
                                Remove-Item $tmpFolder -Recurse -Force
                            }
                            if ($retry) {
                                throw "Error trying to unpack platform artifacts, downloaded package is corrupt"
                            }
                            else {
                                if ($platformUrl -like "https://bcartifacts.azureedge.net/*" -or $platformUrl -like "https://bcinsider.azureedge.net/*" -or $platformUrl -like "https://bcprivate.azureedge.net/*" -or $platformUrl -like "https://bcpublicpreview.azureedge.net/*") {
                                    Write-Host "Error unpacking platform artifact downloaded from CDN, retrying download from direct download URL"
                                    $idx = $platformUrl.IndexOf('.azureedge.net/',[System.StringComparison]::InvariantCultureIgnoreCase)
                                    $platformUrl = $platformUrl.Substring(0,$idx) + '.blob.core.windows.net' + $platformUrl.Substring($idx + 14)
                                    $retry = $true
                                }
                            }
                        }
                    } while ($retry)

                    $downloadprereqs = $false
                    try {
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
                                        $skip = ($_.Name -eq "Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi") -and (([System.Version]$appManifest.Version).Major -ge 21)
                                        $path = Join-Path $platformArtifactPath $_.Name
                                        if ((-not $skip) -and (-not (Test-Path $path))) {
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
                                # Patch potential wrong version of NewtonSoft.json.DLL
                                $newtonSoftDllPath = Join-Path $platformArtifactPath 'ServiceTier\program files\Microsoft Dynamics NAV\210\Service\Newtonsoft.json.dll'
                                if (Test-Path $newtonSoftDllPath) {
                                    'Applications\testframework\TestRunner\Internal\Newtonsoft.json.dll','Test Assemblies\Newtonsoft.json.dll' | ForEach-Object {
                                        $dstFile = Join-Path $platformArtifactPath $_
                                        $file = Get-item -Path $dstFile -ErrorAction SilentlyContinue
                                        if ($file -and $file.Length -eq 686000) {
                                            Write-Host "INFO: Patching wrong version of NewtonSoft.json.DLL in $dstFile"
                                            Copy-Item -Path $newtonSoftDllPath -Destination $dstFile -Force 
                                        }
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
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Download-Artifacts
