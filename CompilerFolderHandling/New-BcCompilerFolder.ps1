<#
 .SYNOPSIS
  Create a new Compiler Folder
 .DESCRIPTION
  Create a folder containing all the necessary pieces from the artifacts to compile apps without the need of a container
  For BC 27 and later, prefer the portable Development.Tools package when included in the platform artifact; otherwise use ALLanguage.vsix.
  Platforms before BC 27 retain VSIX-based compiler selection, including Marketplace latest/preview.
  Select the tools target framework from Microsoft.Dynamics.Nav.Ncl.dll in the platform artifact and require a compatible installed .NET runtime.
  Inspecting platform assembly metadata for tools packages requires PowerShell 7.
  Existing compiler caches are reused; recreate them to change compiler source.
  Returns a compilerFolder path, which can be used for functions like Compile-AppWithBcCompilerFolder or Remove-BcCompilerFolder
 .PARAMETER artifactUrl
  Artifacts URL to download the compiler and all .app files from
 .PARAMETER platformArtifactUrl
  Url for platform artifact to use. Use this when you want to use a different platform than the one related to artifactUrl.
 .PARAMETER containerName
  Name of the folder in which to create the compiler folder or empty to use a default name consisting of type-version-country
 .PARAMETER cacheFolder
  If present:
  - if the cacheFolder exists, the artifacts will be grabbed from here instead of downloaded.
  - if the cacheFolder doesn't exist, it is created and populated with the needed content from the ArtifactURL
 .PARAMETER packagesFolder
  If present, the symbols/apps will be copied from the compiler folder to this folder as well
 .PARAMETER vsixFile
  If present, use this vsixFile instead of the tools package or VSIX included in the artifacts
  Use latest or preview to download Development.Tools from the compiler NuGet source (preview allows prereleases), matching the platform target framework.
  The tools major version is the platform major minus 11 before BC 30, and the platform major from BC 30 onward.
 .PARAMETER compilerNuGetServerUrl
  NuGet v3 service index for latest/preview compiler packages on BC 27 and later. Defaults to NuGet.org.
 .PARAMETER compilerNuGetToken
  Optional authentication token for the compiler NuGet source. Use a secret variable; the token is not logged.
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
        [string] $platformArtifactUrl = '',
        [string] $containerName = '',
        [string] $cacheFolder = '',
        [string] $packagesFolder = '',
        [string] $vsixFile = '',
        [switch] $includeAL,
        [string] $compilerNuGetServerUrl = 'https://api.nuget.org/v3/index.json',
        [string] $compilerNuGetToken = ''
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    if ($platformArtifactUrl -and -not $artifactUrl) {
        throw "You have to specify artifactUrl when using platformArtifactUrl."
    }
    $parts = $artifactUrl.Split('?')[0].Split('/')
    if ($parts.Count -lt 6) {
        throw "Invalid artifact URL"
    }
    $type = $parts[3]
    $version = [System.Version]($parts[4])
    $country = $parts[5]

    $vsixFile = DetermineVsixFile -vsixFile $vsixFile -useCompilerFolder
    $compilerOverride = [bool]$vsixFile

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
    $platformArtifactPath = ''
    $compilerSource = $null
    $compilerDestination = if ($compilerOverride) { Join-Path $compilerFolder 'compiler' } else { $compilerPath }
    $populateCompiler = !$compilerOverride -and !(Test-Path $compilerPath)
    if ($includeAL -or !(Test-Path $symbolsPath) -or $populateCompiler -or ($vsixFile -in @('latest', 'preview'))) {
        $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -platformArtifactUrl $platformArtifactUrl -includePlatform
        $appArtifactPath = $artifactPaths[0]
        $platformArtifactPath = $artifactPaths[1]
        $newtonSoftDllPath = Join-Path $platformArtifactPath "ServiceTier\*\Microsoft Dynamics NAV\*\Service\Newtonsoft.Json.dll" -Resolve
    }

    if ($populateCompiler -or $compilerOverride) {
        $compilerSource = ResolveBcCompilerSource -platformArtifactPath $platformArtifactPath -vsixFile $vsixFile -nuGetServerUrl $compilerNuGetServerUrl -nuGetToken $compilerNuGetToken
        InstallBcCompilerSource -source $compilerSource -destinationPath $compilerDestination
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
                $baseAppSource = @(get-childitem -Path (Join-Path $platformArtifactPath "?pplications") -recurse -filter "Base Application.Source.zip")
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
        New-Item $dllsPath -ItemType Directory | Out-Null
        # Enumerate subfolders to ensure we support different casings in folder structure
        $modernDevFolder = Join-Path $platformArtifactPath "ModernDev\*\Microsoft Dynamics NAV\*\AL Development Environment"
        $modernDevFolder = Get-ChildItem -Recurse -Directory -Path $platformArtifactPath | Where-Object { $_.FullName -like $modernDevFolder } | ForEach-Object { $_.FullName }
        Copy-Item -Path (Join-Path $modernDevFolder 'System.app') -Destination $symbolsPath
        $serviceTierFolder = Join-Path $platformArtifactPath "ServiceTier\*\Microsoft Dynamics NAV\*\Service" -Resolve
        Copy-Item -Path $serviceTierFolder -Filter '*.dll' -Destination $dllsPath -Recurse
        $newtonSoftDllPath = Join-Path $dllsPath "Newtonsoft.Json.dll"
        Remove-Item -Path (Join-Path $dllsPath 'Service\Management') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $dllsPath 'Service\WindowsServiceInstaller') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $dllsPath 'Service\SideServices') -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path $dllsPath 'OpenXML') -ItemType Directory | Out-Null
        Copy-Item -Path (Join-Path $dllsPath 'Service\DocumentFormat.OpenXml.dll') -Destination (Join-Path $dllsPath 'OpenXML') -Force -ErrorAction SilentlyContinue
        $testAssembliesFolder = Join-Path $platformArtifactPath "Test Assemblies" -Resolve
        $testAssembliesDestination = Join-Path $dllsPath "Test Assemblies"
        New-Item -Path $testAssembliesDestination -ItemType Directory | Out-Null
        Copy-Item -Path (Join-Path $testAssembliesFolder 'Newtonsoft.Json.dll') -Destination $testAssembliesDestination -Force -ErrorAction SilentlyContinue
        Copy-Item -Path (Join-Path $testAssembliesFolder 'Microsoft.Dynamics.Framework.UI.Client.dll') -Destination $testAssembliesDestination -Force
        $mockAssembliesFolder = Join-Path $testAssembliesFolder "Mock Assemblies" -Resolve
        Copy-Item -Path $mockAssembliesFolder -Filter '*.dll' -Destination $dllsPath -Recurse
        # Use questionmark as different versions of BC have different casing of the folder name (extensions/Extensions and applications/Applications)
        $extensionsFolder = Join-Path $appArtifactPath '?xtensions' -Resolve
        if ($extensionsFolder) {
            Write-Host "Copying app files from $extensionsFolder"
            Copy-Item -Path (Join-Path $extensionsFolder '*.app') -Destination $symbolsPath
            $platformAppsPath = Join-Path $platformArtifactPath '?pplications' -Resolve
            $appAppsPath = Join-Path $AppArtifactPath '?pplications.*' -Resolve

            $platformApps = @(Get-ChildItem -Path $platformAppsPath -Filter '*.app' -Recurse)
            Write-Host "PlatForm apps"
            $platformApps | ForEach-Object { Write-Host "- $($_.Name)" }
            $appApps = @()
            if ($appAppsPath) {
                $appApps = @(Get-ChildItem -Path $appAppsPath -Filter '*.app' -Recurse)
                Write-Host "App apps"
                $appApps | ForEach-Object { Write-Host "- $($_.Name)" }
            }
            'Microsoft_Tests-*.app','Microsoft_Performance Toolkit Samples*.app','Microsoft_Performance Toolkit Tests*.app','Microsoft_System Application Test Library*.app','Microsoft_TestRunner-Internal*.app','Microsoft_Business Foundation Test Libraries*.app','Microsoft_AI Test Toolkit*.app','Microsoft_Application Test Library*.app' | ForEach-Object {
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
            $platformAppsPath = Join-Path $platformArtifactPath '?pplications' -Resolve
            $appAppsPath = Join-Path $AppArtifactPath '?pplications' -Resolve
            if ($appAppsPath) {
                Get-ChildItem -Path $appAppsPath -Filter '*.app' -Recurse | ForEach-Object { Copy-Item -Path $_.FullName -Destination $symbolsPath }
            }
            else {
                Get-ChildItem -Path $platformAppsPath -Filter '*.app' -Recurse | ForEach-Object { Copy-Item -Path $_.FullName -Destination $symbolsPath }
            }
        }
        # Copy manifest.json for .NET version resolution during compilation
        $manifestSource = Join-Path $appArtifactPath "manifest.json"
        if (Test-Path $manifestSource) {
            $manifestDest = if ($cacheFolder) { $cacheFolder } else { $compilerFolder }
            Copy-Item -Path $manifestSource -Destination (Join-Path $manifestDest "manifest.json") -Force
        }
    }

    $dotNetSharedFolder = Join-Path $dllsPath 'shared'
    $portableTools = Test-Path (Join-Path $compilerDestination 'compiler.runtime.json')
    if (!$portableTools -and $version -ge "22.0.0.0" -and (!(Test-Path $dotNetSharedFolder)) -and ($dotNetRuntimeVersionInstalled -lt [System.Version]$bcContainerHelperConfig.MinimumDotNetRuntimeVersionStr)) {
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
    if ($compilerSource -and $compilerSource.Kind -eq 'ExplicitVsix' -and $isWindows -and $newtonSoftDllPath) {
        Copy-Item -Path $newtonSoftDllPath -Destination (Join-Path $containerCompilerPath 'extension\bin') -Force -ErrorAction SilentlyContinue
    }

    # If a cacheFolder was specified, the cache folder has been populated
    if ($cacheFolder) {
        Write-Host "Copying DLLs from cache"
        Copy-Item -Path $dllsPath -Filter '*.dll' -Destination $compilerFolder -Recurse -Force
        Write-Host "Copying symbols from cache"
        Copy-Item -Path $symbolsPath -Filter '*.app' -Destination $compilerFolder -Recurse -Force
        # If a vsix file was specified, the compiler folder has been populated
        if (!$compilerOverride) {
            Write-Host "Copying compiler from cache"
            Copy-Item -Path $compilerPath -Destination $compilerFolder -Recurse -Force
        }
        # Copy manifest.json from cache to compiler folder
        $cachedManifest = Join-Path $cacheFolder "manifest.json"
        if (Test-Path $cachedManifest) {
            Copy-Item -Path $cachedManifest -Destination (Join-Path $compilerFolder "manifest.json") -Force
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
            # Old VSIX layout with platform-specific subdirs
            if (Test-Path $alToolExePath) {
                # Set execute permissions on altool
                if ($isLinux) {
                    & /usr/bin/env sudo pwsh -command "& chmod +x $alToolExePath"
                } else {
                    & chmod +x $alToolExePath
                }
            }
            # Set execute permissions on alc
            if ($isLinux) {
                & /usr/bin/env sudo pwsh -command "& chmod +x $alcExePath"
            } else {
                & chmod +x $alcExePath
            }
        } else {
            # New VSIX layout (flat bin/) or old layout needing runtimeconfig patching
            $alcConfigPath = Join-Path $containerCompilerPath 'extension/bin/win32/alc.runtimeconfig.json'
            if (-not (Test-Path $alcConfigPath)) {
                $alcConfigPath = Join-Path $containerCompilerPath 'extension/bin/alc.runtimeconfig.json'
            }
            if (Test-Path $alcConfigPath) {
                $oldAlcConfig = Get-Content -Path $alcConfigPath -Encoding UTF8 | ConvertFrom-Json
                if ($oldAlcConfig.runtimeOptions.PSObject.Properties.Name -eq 'includedFrameworks') {
                    # Old self-contained VSIX: patch runtimeconfig for Linux/macOS
                    Write-Host "Patching alc.runtimeconfig.json for use with $($compilerPlatform)"
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
                # else: new framework-dependent VSIX already has "framework" key, no patching needed
            }
        }
    }

    Write-Host "Enumerating Apps in $symbolsPath"
    $compilerFolderAppFiles = @(Get-ChildItem -Path (Join-Path $symbolsPath '*.app') | Select-Object -ExpandProperty FullName)
    GetAppInfo -AppFiles $compilerFolderAppFiles -compilerFolder $compilerFolder -cacheAppinfoPath (Join-Path $symbolsPath 'cache_AppInfo.json') | Out-Null
    if ($cacheFolder) {
        Write-Host "Copying symbols cache"
        Copy-Item -Path (Join-Path $symbolsPath 'cache_AppInfo.json') -Destination (Join-Path $compilerFolder 'symbols') -Force
        $templatesFolder = Join-Path $cacheFolder "compiler\extension\templates"
        if (Test-Path $templatesFolder) {
            Write-Host "Removing Templatest Folder"
            Remove-Item $templatesFolder -Recurse -Force
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
