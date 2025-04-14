<#
 .Synopsis
  Download Artifacts
 .Description
  Download artifacts from artifacts storage
 .Parameter artifactUrl
  Url for artifact to use.
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
        [int]    $timeout = $bccontainerHelperConfig.artifactDownloadTimeout
    )

    function DownloadPackage {
        Param(
            [string] $artifactUrl,
            [string] $destinationPath,
            [int]    $timeout = 300
        )

        $tmpFolder = Join-Path ([System.IO.Path]::GetDirectoryName($destinationPath)) ([System.IO.Path]::GetRandomFileName())
        $zipFile = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
        $retry = $false
        do {
            Download-File -sourceUrl $artifactUrl -destinationFile $zipFile -timeout $timeout
            Write-Host "Unpacking artifact to tmp folder " -NoNewline
            try {
                Expand-7zipArchive -Path $zipFile -DestinationPath $tmpFolder -use7zipIfAvailable:(!$retry)
                $retry = $false
            }
            catch {
                Remove-Item -path $zipFile -force
                if (Test-Path $tmpFolder) {
                    Remove-Item $tmpFolder -Recurse -Force
                }
                if ($retry) {
                    throw "Error trying to unpack artifact, downloaded package is corrupt"
                }
                else {
                    if ($artifactUrl -match '^https:\/\/(.+)\.azureedge\.net\/(.*)$') {
                        Write-Host "Error unpacking platform artifact downloaded from CDN, retrying download from direct download URL"
                        $artifactUrl = "https://$($Matches[1]).blob.core.windows.net/$($Matches[2])"
                        $retry = $true
                    }
                }
            }
        } while ($retry)
        $result = $false
        try {
            $attempts = 0
            while (!(Test-Path $destinationPath)) {
                try {
                    Rename-Item -Path $tmpFolder -NewName ([System.IO.Path]::GetFileName($destinationPath)) -Force
                    $result = $true
                }
                catch {
                    if ($attempts++ -eq 5) {
                        throw
                    }
                    $waittime = 5*$attempts
                    Write-Host "Could not rename '$tmpFolder' retrying in $waittime seconds."
                    Start-Sleep -Seconds $waittime
                    Write-Host "Retrying..."
                }
            }
        }
        finally {
            if (Test-Path $zipFile) {
                Remove-Item -path $zipFile -force
            }
            if (Test-Path $tmpFolder) {
                Remove-Item $tmpFolder -Recurse -Force
            }
        }
        return $result
    }


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
                Write-Host "Waiting for other process downloading artifact '$($artifactUrl.Split('?')[0])'"
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
                Write-Host "Downloading artifact $($appUri.AbsolutePath)"
                DownloadPackage -artifactUrl $artifactUrl -destinationPath $appArtifactPath -timeout $timeout | Out-Null
            }
            try { [System.IO.File]::WriteAllText((Join-Path $appArtifactPath 'lastused'), "$([datetime]::UtcNow.Ticks)") } catch {}

            $appManifestPath = Join-Path $appArtifactPath "manifest.json"
            if (Test-Path $appManifestPath) {
                $appManifest = Get-Content $appManifestPath | ConvertFrom-Json

                # Patch wrong license file in ONPREM AU version 20.5.45456.45889
                if ($artifactUrl -like '*/onprem/20.5.45456.45889/au') {
                    Write-Host "INFO: Patching wrong license file in ONPREM AU version 20.5.45456.45889"
                    Download-File -sourceUrl 'https://bcartifacts.blob.core.windows.net/prerequisites/21demolicense/au/3048953.flf' -destinationFile (Join-Path $appArtifactPath 'database/Cronus.flf')
                }
                
                $cuFixMapping = @{
                    '11.0.48794.0' = 'cu53';
                    '11.0.48962.0' = 'cu54';
                    '11.0.49061.0' = 'cu55';
                    '11.0.49175.0' = 'cu56';
                    '11.0.49240.0' = 'cu57';
                    '11.0.49345.0' = 'cu58';
                    '11.0.49497.0' = 'cu59';
                    '11.0.49618.0' = 'cu60';
                }
                if ($appManifest.version -in $cuFixMapping.Keys) {
                    $appManifest.cu = $cuFixMapping[$appManifest.version]
                    $appManifest | ConvertTo-Json | Set-Content -Path $appManifestPath
                }
        
                if ($appManifest.PSObject.Properties.name -eq "applicationUrl") {
                    $redir = $true
                    $artifactUrl = $appManifest.ApplicationUrl
                    if ($artifactUrl -notlike 'https://*') {
                        $artifactUrl = "https://$($appUri.Host)/$artifactUrl$($appUri.Query)"
                    }
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
    
            $PlatformMutexName = "dl-$($platformUrl.Split('?')[0].Substring(8).Replace('/','_'))"
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
                    $downloadprereqs = DownLoadPackage -ArtifactUrl $platformUrl -DestinationPath $platformArtifactPath -timeout $timeout
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
                        # Patch potential wrong version of Newtonsoft.Json.dll
                        $newtonSoftDllPath = Join-Path $platformArtifactPath 'ServiceTier\program files\Microsoft Dynamics NAV\210\Service\Newtonsoft.Json.dll'
                        if (Test-Path $newtonSoftDllPath) {
                            'Applications\testframework\TestRunner\Internal\Newtonsoft.Json.dll','Test Assemblies\Newtonsoft.Json.dll' | ForEach-Object {
                                $dstFile = Join-Path $platformArtifactPath $_
                                $file = Get-item -Path $dstFile -ErrorAction SilentlyContinue
                                if ($file -and $file.Length -eq 686000) {
                                    Write-Host "INFO: Patching wrong version of Newtonsoft.Json.dll in $dstFile"
                                    Copy-Item -Path $newtonSoftDllPath -Destination $dstFile -Force 
                                }
                            }
                        }
                        $ad1DLL = Join-Path $platformArtifactPath 'Applications\testframework\TestRunner\Internal\Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
                        $ad2DLL = Join-Path $platformArtifactPath 'ServiceTier\*\Microsoft Dynamics NAV\*\Service\Management\Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
                        if ((Test-Path $ad1DLL) -and (Test-Path $ad2DLL)) {
                            if ((Get-Item $ad1DLL).Length -ne (Get-Item $ad2DLL).Length) {
                                Write-Host "INFO: Patching wrong version of Microsoft.IdentityModel.Clients.ActiveDirectory.dll in $ad1DLL"
                            }
                            Copy-Item -Path $ad2DLL -Destination $ad1DLL -Force
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