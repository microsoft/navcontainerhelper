<#
 .SYNOPSIS
  Create a new Compiler Folder
 .DESCRIPTION
  Create a folder containing all the necessary pieces from the artifatcs to compile apps without the need of a container
  Returns a compilerFolder path, which can be used for functions like Compile-AppWithBcCompilerFolder or Remove-BcCompilerFolder
 .PARAMETER artifactUrl
  Artifacts URL to download the compiler and all .app files from
 .PARAMETER containerName
  Name of the folder in which to create the compiler folder or empty to use a default name consisting of type-version-country
 .PARAMETER cacheFolder
  If present:
  - if the cacheFolder exists, the artifacts will be grabbed from here instead of downloaded.
  - if the cacheFolder doesn't exist, it is created and populated with the needed content from the ArtifactURL
 .PARAMETER packagesFolder
  If present, the symbols/apps will be copied from the compiler folder to this folder as well
 .PARAMETER vsixFile
  If present, use this vsixFile instead of the one included in the artifacts
 .PARAMETER includeAL
  Include this switch in order to populate folder with AL files (like New-BcContainer)
 .EXAMPLE
  $version = $artifactURL.Split('/')[4]
  $country = $artifactURL.Split('/')[5]
  $compilerFolder = New-BcCompilerFolder -artifactUrl $artifactURL -includeAL
  $baseAppSource = Join-Path $compilerFolder "BaseApp"
  Copy-Item -Path (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\Original-$version-$country-al") $baseAppSource -Container -Recurse
  Compile-AppWithBcCompilerFolder `
      -compilerFolder $compilerFolder `
      -appProjectFolder $baseAppSource `
      -appOutputFolder (Join-Path $compilerFolder '.output') `
      -appSymbolsFolder (Join-Path $compilerFolder 'symbols') `
      -CopyAppToSymbolsFolder
#>
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

    $vsixFile = DetermineVsixFile -vsixFile $vsixFile

    if ($version -lt "16.0.0.0") {
        throw "Containerless compiling is not supported with versions before 16.0"
    }
    
    if (!$containerName) {
        $containerName = [GUID]::NewGuid().ToString()
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
        $symbolsPath = Join-Path $compilerFolder 'symbols'
        $compilerPath = Join-Path $compilerFolder 'compiler'
        $dllsPath = Join-Path $compilerFolder 'dlls'
    }

    $newtonSoftDllPath = ''
    if ($includeAL -or !(Test-Path $symbolsPath)) {
        $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
        $appArtifactPath = $artifactPaths[0]
        $platformArtifactPath = $artifactPaths[1]
        $newtonSoftDllPath = Join-Path $platformArtifactPath "ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Newtonsoft.Json.dll" -Resolve
    }

    # IncludeAL will populate folder with AL files (like New-BcContainer)
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

    # Populate cache folder (or compiler folder)
    if (!(Test-Path $symbolsPath)) {
        New-Item $symbolsPath -ItemType Directory | Out-Null
        New-Item $compilerPath -ItemType Directory | Out-Null
        New-Item $dllsPath -ItemType Directory | Out-Null
        $modernDevFolder = Join-Path $platformArtifactPath "ModernDev\program files\Microsoft Dynamics NAV\*\AL Development Environment" -Resolve
        Copy-Item -Path (Join-Path $modernDevFolder 'System.app') -Destination $symbolsPath
        if ($cacheFolder -or !$vsixFile) {
            # Only unpack the artifact vsix file if we are populating a cache folder - or no vsixFile was specified
            Expand-7zipArchive -Path (Join-Path $modernDevFolder 'ALLanguage.vsix') -DestinationPath $compilerPath
        }
        $serviceTierFolder = Join-Path $platformArtifactPath "ServiceTier\program files\Microsoft Dynamics NAV\*\Service" -Resolve
        Copy-Item -Path $serviceTierFolder -Filter '*.dll' -Destination $dllsPath -Recurse
        $newtonSoftDllPath = Join-Path $dllsPath "Newtonsoft.Json.dll"
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
            $platformAppsPath = Join-Path $platformArtifactPath 'Applications'
            $appAppsPath = Join-Path $AppArtifactPath 'Applications.*' -Resolve
            
            $platformApps = @(Get-ChildItem -Path $platformAppsPath -Filter '*.app' -Recurse)
            $appApps = @()
            if ($appAppsPath) {
                $appApps = @(Get-ChildItem -Path $appAppsPath -Filter '*.app' -Recurse)
            }
            'Microsoft_Tests-*.app','Microsoft_Performance Toolkit Samples*.app','Microsoft_Performance Toolkit Tests*.app','Microsoft_System Application Test Library*.app','Microsoft_TestRunner-Internal*.app' | ForEach-Object {
                $appName = $_
                $apps = $appApps | Where-Object { $_.Name -like $appName }
                if (!$apps) {
                    $apps = $platformApps | Where-Object { $_.Name -like $appName }
                }
                $apps | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination $symbolsPath
                }
            }
        }
        else {
            $platformAppsPath = Join-Path $platformArtifactPath 'Applications'
            $appAppsPath = Join-Path $AppArtifactPath 'Applications'
            if (Test-Path $appAppsPath -PathType Container) {
                Get-ChildItem -Path $appAppsPath -Filter '*.app' -Recurse | ForEach-Object { Copy-Item -Path $_.FullName -Destination $symbolsPath }
            }
            else {
                Get-ChildItem -Path $platformAppsPath -Filter '*.app' -Recurse | ForEach-Object { Copy-Item -Path $_.FullName -Destination $symbolsPath }
            }
        }
    }

    $dotNetSharedFolder = Join-Path $dllsPath 'shared'
    if ($version -ge "22.0.0.0" -and (!(Test-Path $dotNetSharedFolder)) -and ($dotNetRuntimeVersionInstalled -lt [System.Version]$bcContainerHelperConfig.MinimumDotNetRuntimeVersionStr)) {
        if ("$dotNetRuntimeVersionInstalled" -eq "0.0.0") {
            Write-Host "dotnet runtime version is not installed/cannot be used"
        }
        else {
            Write-Host "dotnet runtime version $dotNetRuntimeVersionInstalled is installed, but minimum required version is $($bcContainerHelperConfig.MinimumDotNetRuntimeVersionStr)"
        }
        Write-Host "Downloading minimum required dotnet version from $($bcContainerHelperConfig.MinimumDotNetRuntimeVersionUrl)"
        $dotnetFolder = Join-Path $compilerFolder 'dotnet'
        $dotnetZipFile = "$($dotnetFolder).zip"
        Download-File -sourceUrl $bcContainerHelperConfig.MinimumDotNetRuntimeVersionUrl -destinationFile $dotnetZipFile
        Expand-7zipArchive -Path $dotnetZipFile -DestinationPath $dotnetFolder
        Move-Item -Path (Join-Path $dotnetFolder 'shared') -Destination $dllsPath
        Remove-Item -Path $dotnetZipFile -Force
        Remove-Item -Path $dotnetFolder -Recurse -Force
    }

    $containerCompilerPath = Join-Path $compilerFolder 'compiler'
    if ($vsixFile) {
        # If a vsix file was specified unpack directly to compilerfolder
        Write-Host "Using $vsixFile"
        $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "alc.$containerName.zip"
        Download-File -sourceUrl $vsixFile -destinationFile $tempZip
        Expand-7zipArchive -Path $tempZip -DestinationPath $containerCompilerPath
        if ($isWindows -and $newtonSoftDllPath) {
            Copy-Item -Path $newtonSoftDllPath -Destination (Join-Path $containerCompilerPath 'extension\bin') -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    }

    # If a cacheFolder was specified, the cache folder has been populated
    if ($cacheFolder) {
        Write-Host "Copying DLLs from cache"
        Copy-Item -Path $dllsPath -Filter '*.dll' -Destination $compilerFolder -Recurse -Force
        Write-Host "Copying symbols from cache"
        Copy-Item -Path $symbolsPath -Filter '*.app' -Destination $compilerFolder -Recurse -Force
        # If a vsix file was specified, the compiler folder has been populated
        if (!$vsixFile) {
            Write-Host "Copying compiler from cache"
            Copy-Item -Path $compilerPath -Destination $compilerFolder -Recurse -Force
        }
    }

    # If a packagesFolder was specified, copy symbols from CompilerFolder
    if ($packagesFolder) {
        Write-Host "Copying symbols to packagesFolder"
        New-Item -Path $packagesFolder -ItemType Directory -Force | Out-Null
        Copy-Item -Path $symbolsPath -Filter '*.app' -Destination $packagesFolder -Force -Recurse
    }

    if ($isLinux -or $isMacOS) {
        $compilerPlatform = 'linux'
        if ($isMacOS) {
            $compilerPlatform = 'darwin'
        }
        $alcExePath = Join-Path $containerCompilerPath "extension/bin/$($compilerPlatform)/alc"
        $alToolExePath = Join-Path $containerCompilerPath "extension/bin/$($compilerPlatform)/altool"

        if (Test-Path $alcExePath) {
            if (Test-Path $alToolExePath) {
                # Set execute permissions on altool
                Write-Host "Setting execute permissions on altool"
                if ($isLinux) {
                    & /usr/bin/env sudo pwsh -command "& chmod +x $alToolExePath"
                } else {
                    & chmod +x $alToolExePath
                }
            }
            # Set execute permissions on alc
            Write-Host "Setting execute permissions on alc"
            if ($isLinux) {
                & /usr/bin/env sudo pwsh -command "& chmod +x $alcExePath"
            } else {
                & chmod +x $alcExePath
            }
        } else {
            # Patch alc.runtimeconfig.json for use with Linux or macOS
            Write-Host "Patching alc.runtimeconfig.json for use with $($compilerPlatform)"
            $alcConfigPath = Join-Path $containerCompilerPath 'extension/bin/win32/alc.runtimeconfig.json'
            if (Test-Path $alcConfigPath) {
                $oldAlcConfig = Get-Content -Path $alcConfigPath -Encoding UTF8 | ConvertFrom-Json
                if ($oldAlcConfig.runtimeOptions.PSObject.Properties.Name -eq 'includedFrameworks') {
                    $newAlcConfig = @{
                        "runtimeOptions" = @{
                            "tfm" = "net6.0"
                            "framework" = @{
                                "name" = "Microsoft.NETCore.App"
                                "version" = $oldAlcConfig.runtimeOptions.includedFrameworks[0].version
                            }
                            "configProperties" = @{
                                "System.Reflection.Metadata.MetadataUpdater.IsSupported" = $false
                            }
                        }
                    }
                    $newAlcConfig | ConvertTo-Json | Set-Content -Path $alcConfigPath -Encoding utf8NoBOM
                }
            }
        }       
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
