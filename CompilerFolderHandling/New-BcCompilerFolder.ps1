function New-BcCompilerFolder {
    Param(
        [string] $artifactUrl,
        [string] $containerName = '',
        [string] $cacheFolder = '',
        [string] $packagesFolder = '',
        [string] $vsixFile = '',
        [switch] $includeAL
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $parts = $artifactUrl.Split('?')[0].Split('/')
    if ($parts.Count -lt 6) {
        throw "Invalid artifact URL"
    }
    $type = $parts[3]
    $version = [System.Version]($parts[4])
    $country = $parts[5]

    if ($version -lt "16.0.0.0") {
        throw "Containerless compiling is not supported with versions before 16.0"
    }
    
    if (!$containerName) {
        $containerName = "$type-$version-$country"
    }

    $compilerFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "compiler\$containerName"
    if (Test-Path $compilerFolder) {
        Remove-Item -Path $compilerFolder -Force -Recurse -ErrorAction Ignore
    }
    New-Item -Path $compilerFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    # Populate artifacts cache
    if ($cacheFolder) {
        $symbolsPath = Join-Path $cacheFolder 'symbols'
        $compilerPath = Join-Path $cacheFolder 'compiler'
        $dllsPath = Join-Path $cacheFolder 'dlls'
    }
    else {
        if ($packagesFolder) {
            $symbolsPath = $packagesFolder
        }
        else {
            $symbolsPath = Join-Path $compilerFolder 'symbols'
        }
        $compilerPath = Join-Path $compilerFolder 'compiler'
        $dllsPath = Join-Path $compilerFolder 'dlls'
    }

    if ($includeAL -or !(Test-Path $symbolsPath)) {
        $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
        $appArtifactPath = $artifactPaths[0]
        $platformArtifactPath = $artifactPaths[1]
    }

    if ($includeAL) {
        $alFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\Original-$version-$country-al"
        if (!(Test-Path $alFolder) -or (Get-ChildItem -Path $alFolder -Recurse | Measure-Object).Count -eq 0) {
            if (!(Test-Path $alFolder)) {
                New-Item $alFolder -ItemType Directory | Out-Null
            }
            $countryApplicationsFolder = Join-Path $appArtifactPath "Applications.$country"
            if (Test-Path $countryApplicationsFolder) {
                $baseAppSource = @(get-childitem -Path $countryApplicationsFolder -recurse -filter "Base Application.Source.zip")
            }
            else {
                $baseAppSource = @(get-childitem -Path (Join-Path $platformArtifactPath "Applications") -recurse -filter "Base Application.Source.zip")
            }
            if ($baseAppSource.Count -ne 1) {
                throw "Unable to locate Base Application.Source.zip"
            }
            Write-Host "Extracting $($baseAppSource[0].FullName)"
            Expand-7zipArchive -Path $baseAppSource[0].FullName -DestinationPath $alFolder
        }
    }

    if (!(Test-Path $symbolsPath)) {
        New-Item $symbolsPath -ItemType Directory | Out-Null
        New-Item $compilerPath -ItemType Directory | Out-Null
        New-Item $dllsPath -ItemType Directory | Out-Null
        $modernDevFolder = Join-Path $platformArtifactPath "ModernDev\program files\Microsoft Dynamics NAV\*\AL Development Environment" -Resolve
        Copy-Item -Path (Join-Path $modernDevFolder 'System.app') -Destination $symbolsPath
        if ($cacheFolder -or !$vsixFile) {
            Expand-7zipArchive -Path (Join-Path $modernDevFolder 'ALLanguage.vsix') -DestinationPath $compilerPath
        }
        $serviceTierFolder = Join-Path $platformArtifactPath "ServiceTier\program files\Microsoft Dynamics NAV\*\Service" -Resolve
        Copy-Item -Path $serviceTierFolder -Filter '*.dll' -Destination $dllsPath -Recurse
        Remove-Item -Path (Join-Path $dllsPath 'Service\Management') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $dllsPath 'Service\WindowsServiceInstaller') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $dllsPath 'Service\SideServices') -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path $dllsPath 'OpenXML') -ItemType Directory | Out-Null
        Copy-Item -Path (Join-Path $dllsPath 'Service\DocumentFormat.OpenXml.dll') -Destination (Join-Path $dllsPath 'OpenXML') -Force -ErrorAction SilentlyContinue
        $mockAssembliesFolder = Join-Path $platformArtifactPath "Test Assemblies\Mock Assemblies" -Resolve
        Copy-Item -Path $mockAssembliesFolder -Filter '*.dll' -Destination $dllsPath -Recurse
        $extensionsFolder = Join-Path $appArtifactPath 'Extensions'
        if (Test-Path $extensionsFolder -PathType Container) {
            Copy-Item -Path (Join-Path $extensionsFolder '*.app') -Destination $symbolsPath
        }
    }

    $containerCompilerPath = Join-Path $compilerFolder 'compiler'
    if ($vsixFile) {
        Write-Host "Using $vsixFile"
        $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "alc.zip"
        Download-File -sourceUrl $vsixFile -destinationFile $tempZip
        Expand-7zipArchive -Path $tempZip -DestinationPath $containerCompilerPath
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    }

    if ($cacheFolder) {
        Write-Host "Copying DLLs from cache"
        Copy-Item -Path $dllsPath -Filter '*.dll' -Destination $compilerFolder -Recurse -Force
        if (!$vsixFile) {
            Write-Host "Copying compiler from cache"
            Copy-Item -Path $compilerPath -Destination $compilerFolder -Recurse -Force
        }
        if ($packagesFolder) {
            Write-Host "Copying symbols from cache"
            New-Item -Path $packagesFolder -ItemType Directory -Force | Out-Null
            Copy-Item -Path (Join-Path $symbolsPath '*.app') -Destination $packagesFolder -Force -Recurse
        }
        else {
            Write-Host "Copying Symbols from cache"
            Copy-Item -Path $symbolsPath -Destination $compilerFolder -Recurse -Force
        }
    }
    if ($isLinux) {
        $alcExePath = Join-Path $containerCompilerPath 'extension/bin/linux/alc'
        # Set execute permissions on alc
        & /usr/bin/env sudo pwsh -command "& chmod +x $alcExePath"
    }
    $compilerFolder
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function New-BcCompilerFolder
