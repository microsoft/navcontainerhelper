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
 .Parameter basePath
  Load the artifacts into a file structure below this path. (default is c:\bcartifacts.cache)
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
        [string] $basePath = 'c:\bcartifacts.cache'
    )

    if (-not (Test-Path $basePath)) {
        New-Item $basePath -ItemType Directory | Out-Null
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
        if (-not $exists) {
            Write-Host "Downloading application artifact $($appUri.AbsolutePath)"
            $appZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
            Download-File -sourceUrl $artifactUrl -destinationFile $appZip
            Write-Host "Unpacking application artifact"
            Expand-Archive -Path $appZip -DestinationPath $appArtifactPath -Force
            Remove-Item -path $appZip -force
        }
        Set-Content -Path (Join-Path $appArtifactPath 'lastused') -Value "$([datetime]::UtcNow.Ticks)"

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
            $platformUrl = "$($appUri.AbsolutePath.Substring(0,$appUri.AbsolutePath.LastIndexOf('/')))/platform$($appUri.Query)".TrimStart('/')
        }
    
        if ($platformUrl -notlike 'https://*') {
            $platformUrl = "https://$($appUri.Host.TrimEnd('/'))/$platformUrl$($appUri.Query)"
        }
        $platformUri = [Uri]::new($platformUrl)
         
        $platformArtifactPath = Join-Path $basePath $platformUri.AbsolutePath
        $exists = Test-Path $platformArtifactPath
        if ($exists -and $force) {
            Remove-Item $platformArtifactPath -Recurse -Force
            $exists = $false
        }
        if (-not $exists) {
            Write-Host "Downloading platform artifact $($platformUri.AbsolutePath)"
            $platformZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
            Download-File -sourceUrl $platformUrl -destinationFile $platformZip
            Write-Host "Unpacking platform artifact"
            Expand-Archive -Path $platformZip -DestinationPath $platformArtifactPath -Force
            Remove-Item -path $platformZip -force
    
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
                        Download-File -sourceUrl $url -destinationFile $path
                    }
                }
            }
        }
        Set-Content -Path (Join-Path $platformArtifactPath 'lastused') -Value "$([datetime]::UtcNow.Ticks)"
        $platformArtifactPath
    }
}
Export-ModuleMember -Function Download-Artifacts
