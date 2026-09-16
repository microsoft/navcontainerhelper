Describe 'Compiler folder tools (PowerShell 7)' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
BeforeAll {
    $isPsCore = $PSVersionTable.PSEdition -eq 'Core'
    $repoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $PSScriptRoot '_LoadCompilerFolderFunctions.ps1') -repoRoot $repoRoot
    function Expand-7zipArchive {
        [CmdletBinding()]
        param($Path, $DestinationPath)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
    }
    function Download-Artifacts { param($artifactUrl, $platformArtifactUrl, [switch]$includePlatform) }
    function Download-File { [CmdletBinding()] param($sourceUrl, $destinationFile, $headers) }
    function InitTelemetryScope { param($name, $parameterValues, $includeParameters) }
    function TrackException { param($telemetryScope, $errorRecord) }
    function TrackTrace { param($telemetryScope) }
    function GetLatestAlLanguageExtensionVersionAndUrl { param([switch]$allowPrerelease) }
    function InvokeTestDotnet { $global:LASTEXITCODE = 0; $script:runtimeLines }

    $script:platform8 = Join-Path $TestDrive 'platform8.dll'
    $script:platform10 = Join-Path $TestDrive 'platform10.dll'
    $script:platform26 = Join-Path $TestDrive 'platform26.dll'
    foreach ($fixture in @(@{ Path = $platform8; Net = 8; BC = 28 }, @{ Path = $platform10; Net = 10; BC = 30 }, @{ Path = $platform26; Net = 8; BC = 26 })) {
        $typeName = 'PlatformFixture' + [Guid]::NewGuid().ToString('N')
        Add-Type -OutputAssembly $fixture.Path -TypeDefinition @"
using System.Reflection;
using System.Runtime.Versioning;
[assembly: TargetFramework(".NETCoreApp,Version=v$($fixture.Net).0")]
[assembly: AssemblyFileVersion("$($fixture.BC).0.1.0")]
public class $typeName {}
"@
    }
    $packageSource = Join-Path $TestDrive 'package'
    foreach ($major in @(8, 10)) {
        $bin = Join-Path $packageSource "tools\net$major.0\any"
        New-Item -Path (Join-Path $bin 'fr') -ItemType Directory -Force | Out-Null
        foreach ($file in @('alc.dll', 'altool.dll', 'Microsoft.Dynamics.Nav.CodeCop.dll', 'fr\resources.dll')) {
            Set-Content -Path (Join-Path $bin $file) -Value "net$major"
        }
        foreach ($tool in @('alc', 'altool')) {
            @{ runtimeOptions = @{ tfm = "net$major.0"; framework = @{ name = 'Microsoft.NETCore.App'; version = "$major.0.0" } } } |
                ConvertTo-Json -Depth 5 | Set-Content (Join-Path $bin "$tool.runtimeconfig.json")
        }
    }
    $script:package = Join-Path $TestDrive 'microsoft.dynamics.businesscentral.development.tools.17.0.1.nupkg'
    [System.IO.Compression.ZipFile]::CreateFromDirectory($packageSource, $package)
}

Describe 'Portable development tools' {
    BeforeEach {
        $script:runtimeLines = @('Microsoft.NETCore.App 8.0.31 [runtime]', 'Microsoft.NETCore.App 10.0.12 [runtime]')
        Mock Get-Command { [PSCustomObject]@{ Source = 'InvokeTestDotnet' } } -ParameterFilter { $Name -eq 'dotnet' }
        $script:destination = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
    }

    It 'reads net8 and net10 from assembly metadata without loading assemblies' {
        GetAssemblyTargetFramework $platform8 | Should -Be 'net8.0'
        GetAssemblyTargetFramework $platform10 | Should -Be 'net10.0'
    }

    It 'selects net8 for a net8 platform even with net10 installed' {
        ExpandDevelopmentToolsPackage $package $destination $platform8
        Get-Content (Join-Path $destination 'extension\bin\alc.dll') | Should -Be 'net8'
        Get-Content (Join-Path $destination 'extension\bin\Microsoft.Dynamics.Nav.CodeCop.dll') | Should -Be 'net8'
        Get-Content (Join-Path $destination 'extension\bin\fr\resources.dll') | Should -Be 'net8'
        (Get-Content (Join-Path $destination 'compiler.runtime.json') | ConvertFrom-Json).dotNetVersion | Should -Be '8.0.0'
    }

    It 'selects net10 for a net10 platform' {
        ExpandDevelopmentToolsPackage $package $destination $platform10
        Get-Content (Join-Path $destination 'extension\bin\altool.dll') | Should -Be 'net10'
    }

    It 'does not substitute net10 when the required net8 runtime is missing' {
        $script:runtimeLines = @('Microsoft.NETCore.App 10.0.12 [runtime]')
        { ExpandDevelopmentToolsPackage $package $destination $platform8 } | Should -Throw '*No compatible .NET runtime*net8.0*'
        Test-Path $destination | Should -BeFalse
    }

    It 'rejects missing dotnet with an actionable error' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'dotnet' }
        { ExpandDevelopmentToolsPackage $package $destination $platform8 } | Should -Throw '*dotnet was not found*'
    }

    It 'rejects a missing matching compiler target instead of using another framework' {
        Mock GetAssemblyTargetFramework { 'net9.0' }
        { ExpandDevelopmentToolsPackage $package $destination $platform8 } | Should -Throw '*does not contain the net9.0 compiler*'
        Test-Path $destination | Should -BeFalse
    }

    It 'rejects corrupt archives without leaving a compiler cache' {
        $badPackage = Join-Path $TestDrive 'broken.nupkg'
        Set-Content $badPackage 'not a ZIP'
        { ExpandDevelopmentToolsPackage $badPackage $destination $platform8 } | Should -Throw
        Test-Path $destination | Should -BeFalse
    }

    It 'selects the latest matching runtime patch and retains its actual installation path' {
        $script:runtimeLines = @(
            'Microsoft.NETCore.App 8.0.2 [custom runtime]',
            'Microsoft.NETCore.App 8.0.31 [custom runtime]',
            'Microsoft.NETCore.App 10.0.12 [runtime]'
        )
        $runtime = GetCompatibleDotNetRuntime -requiredVersion '8.0.3'
        $runtime.Version | Should -Be ([Version]'8.0.31')
        $runtime.Path | Should -Be (Join-Path 'custom runtime' '8.0.31')
    }

    It 'rejects a runtime older than the compiler minimum patch' {
        $script:runtimeLines = @('Microsoft.NETCore.App 8.0.2 [runtime]')
        { GetCompatibleDotNetRuntime -requiredVersion '8.0.3' } | Should -Throw '*Install .NET 8.0.3*'
    }
}

Describe 'NuGet tools channels' {
    BeforeEach {
        $script:feedVersions = @('16.1.0', '17.1.0', '17.2.0', '17.3.0-beta', '18.1.0', '30.1.0', '30.2.0-beta', '31.1.0')
        Mock Invoke-RestMethod {
            if ($Uri -eq 'https://api.nuget.org/v3/index.json') {
                return @{ resources = @(
                    @{ '@type' = 'SearchQueryService'; '@id' = 'https://test.invalid/search' },
                    @{ '@type' = 'PackagePublish/2.0.0'; '@id' = 'https://test.invalid/publish' },
                    @{ '@type' = 'PackageBaseAddress/3.0.0'; '@id' = 'https://api.nuget.org/v3-flatcontainer' }
                ) }
            }
            return @{ versions = $script:feedVersions }
        }
    }

    It 'maps BC <Platform> to tools <Tools> for latest stable' -TestCases @(
        @{ Platform = '27.0'; Tools = '16.1.0' },
        @{ Platform = '28.0'; Tools = '17.2.0' },
        @{ Platform = '29.0'; Tools = '18.1.0' },
        @{ Platform = '30.0'; Tools = '30.1.0' },
        @{ Platform = '31.0'; Tools = '31.1.0' }
    ) {
        param($Platform, $Tools)
        (GetDevelopmentToolsPackageInfo -platformVersion $Platform).Url | Should -Be "https://api.nuget.org/v3-flatcontainer/microsoft.dynamics.businesscentral.development.tools/$Tools/microsoft.dynamics.businesscentral.development.tools.$Tools.nupkg"
    }

    It 'allows prereleases only within the mapped major for preview' {
        (GetDevelopmentToolsPackageInfo -platformVersion '28.0' -allowPrerelease).Url | Should -BeLike '*/17.3.0-beta/*.17.3.0-beta.nupkg'
        (GetDevelopmentToolsPackageInfo -platformVersion '30.0' -allowPrerelease).Url | Should -BeLike '*/30.2.0-beta/*.30.2.0-beta.nupkg'
    }

    It 'fails if the mapped major is unavailable instead of choosing a different major' {
        { GetDevelopmentToolsPackageInfo -platformVersion '26.0' } | Should -Throw '*Development.Tools 15.x*'
    }

    It 'selects beta.10 over beta.9 regardless of the feed helper lexical ordering' {
        $script:feedVersions = @('30.0.0-beta.9', '30.0.0-beta.10')
        (GetDevelopmentToolsPackageInfo -platformVersion '30.0' -allowPrerelease).Version | Should -Be '30.0.0-beta.10'
    }

    It 'selects stable over prerelease for the same numeric version' {
        $script:feedVersions = @('30.0.0-beta.10', '30.0.0')
        (GetDevelopmentToolsPackageInfo -platformVersion '30.0' -allowPrerelease).Version | Should -Be '30.0.0'
    }

    It 'authenticates both discovery and downloads against a custom feed without logging the token' {
        $feedUrl = 'https://feed.example.invalid/v3/index.json'
        $expectedAuth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('user:test-token'))
        Mock Invoke-RestMethod {
            if ($Uri -eq 'https://feed.example.invalid/v3/index.json') {
                return @{ resources = @(
                    @{ '@type' = 'SearchQueryService'; '@id' = 'https://feed.example.invalid/query' },
                    @{ '@type' = 'PackagePublish/2.0.0'; '@id' = 'https://feed.example.invalid/publish' },
                    @{ '@type' = 'PackageBaseAddress/3.0.0'; '@id' = 'https://feed.example.invalid/flat2' }
                ) }
            }
            return @{ versions = @('17.1.0', '17.2.0-beta', '18.0.0') }
        }
        Mock Write-Host {}
        $info = GetDevelopmentToolsPackageInfo -platformVersion '28.0' -nuGetServerUrl $feedUrl -nuGetToken 'test-token'
        $info.Url | Should -BeLike 'https://feed.example.invalid/flat2/*/17.1.0/*.17.1.0.nupkg'
        $info.Headers.Authorization | Should -Be $expectedAuth
        $info.Headers.ContainsKey('Content-Type') | Should -BeFalse
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Headers.Authorization -eq $expectedAuth -and $Uri -like 'https://feed.example.invalid/*' }
        Should -Invoke Write-Host -Times 0 -ParameterFilter { ($Object -join ' ') -like '*test-token*' -or ($Object -join ' ') -like "*$expectedAuth*" }
    }

    It 'does not send credentials to NuGet.org even if a token was supplied' {
        $info = GetDevelopmentToolsPackageInfo -platformVersion '28.0' -nuGetToken 'test-token'
        $info.Headers.ContainsKey('Authorization') | Should -BeFalse
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Headers.ContainsKey('Authorization') }
    }

    It 'rejects insecure compiler feeds before making a request' {
        { GetDevelopmentToolsPackageInfo -platformVersion '28.0' -nuGetServerUrl 'http://feed.example.invalid/index.json' -nuGetToken 'test-token' } |
            Should -Throw '*HTTPS service index*'
        Should -Invoke Invoke-RestMethod -Times 0
    }
}

Describe 'New-BcCompilerFolder selection and caching' {
    BeforeEach {
        $script:root = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $script:appArtifact = Join-Path $root 'application'
        $script:platformArtifact = Join-Path $root 'platform'
        $script:modernDev = Join-Path $platformArtifact 'ModernDev\1\Microsoft Dynamics NAV\1\AL Development Environment'
        $service = Join-Path $platformArtifact 'ServiceTier\1\Microsoft Dynamics NAV\1\Service'
        $testAssemblies = Join-Path $platformArtifact 'Test Assemblies'
        foreach ($path in @($modernDev, $service, (Join-Path $testAssemblies 'Mock Assemblies'), (Join-Path $platformArtifact 'Applications'), (Join-Path $appArtifact 'Extensions'))) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
        Copy-Item $platform8 (Join-Path $service 'Microsoft.Dynamics.Nav.Ncl.dll')
        Set-Content (Join-Path $service 'Newtonsoft.Json.dll') 'dll'
        Set-Content (Join-Path $testAssemblies 'Microsoft.Dynamics.Framework.UI.Client.dll') 'dll'
        Set-Content (Join-Path $modernDev 'System.app') 'app'
        Set-Content (Join-Path $appArtifact 'manifest.json') '{"dotNetVersion":"10.0.0"}'
        Copy-Item $package $modernDev
        $script:bcContainerHelperConfig = @{
            hostHelperFolder = Join-Path $root 'host'
            MinimumDotNetRuntimeVersionStr = '10.0.0'
        }
        $script:dotNetRuntimeVersionInstalled = [Version]'10.0.0'
        $script:platformMajor = 28
        $script:runtimeLines = @('Microsoft.NETCore.App 8.0.31 [runtime]', 'Microsoft.NETCore.App 10.0.12 [runtime]')
        Mock Get-Command { [PSCustomObject]@{ Source = 'InvokeTestDotnet' } } -ParameterFilter { $Name -eq 'dotnet' }
        Mock Download-Artifacts { @($script:appArtifact, $script:platformArtifact) }
        # Add-Type fixtures have managed attributes but no native file-version resource.
        Mock Get-ChildItem {
            [PSCustomObject]@{
                FullName = Join-Path $script:platformArtifact 'ServiceTier\1\Microsoft Dynamics NAV\1\Service\Microsoft.Dynamics.Nav.Ncl.dll'
                VersionInfo = @{ FileVersion = "$script:platformMajor.0.1.0" }
            }
        } -ParameterFilter { $Path -like '*\Microsoft.Dynamics.Nav.Ncl.dll' }
        Mock GetAppInfo { Set-Content -Path $cacheAppinfoPath '{}' }
        Mock Expand-7zipArchive {
            if ($Path -like '*.vsix') {
                New-Item -Path (Join-Path $DestinationPath 'extension\bin') -ItemType Directory -Force | Out-Null
                Set-Content (Join-Path $DestinationPath 'extension\bin\alc.dll') 'vsix'
            }
            else {
                [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
            }
        }
        Mock GetLatestAlLanguageExtensionVersionAndUrl { throw 'Marketplace must not be queried' }
        $script:artifactUrl = 'https://example.invalid/sandbox/28.0.1.0/w1'
    }

    It 'prefers portable tools over the VSIX and ignores Tools.Win' {
        Set-Content (Join-Path $modernDev 'microsoft.dynamics.businesscentral.development.tools.win.17.0.1.nupkg') 'not used'
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'net8'
        Should -Invoke Expand-7zipArchive -Times 0 -ParameterFilter { $Path -like '*.vsix' }
    }

    It 'resolves source kinds without installing the compiler' {
        (ResolveBcCompilerSource -platformArtifactPath $platformArtifact).Kind | Should -Be 'ArtifactTools'
        (ResolveBcCompilerSource -vsixFile 'explicit.vsix').Kind | Should -Be 'ExplicitVsix'
        Mock GetDevelopmentToolsPackageInfo { @{ Url = 'https://example.invalid/tools.nupkg'; Headers = @{} } }
        (ResolveBcCompilerSource -platformArtifactPath $platformArtifact -vsixFile latest).Kind | Should -Be 'FeedTools'
        $script:platformMajor = 26
        (ResolveBcCompilerSource -platformArtifactPath $platformArtifact).Kind | Should -Be 'ArtifactVsix'
        Should -Invoke Expand-7zipArchive -Times 0
    }

    It 'falls back to VSIX when only Tools.Win is available' {
        Remove-Item (Join-Path $modernDev (Split-Path $package -Leaf))
        Set-Content (Join-Path $modernDev 'microsoft.dynamics.businesscentral.development.tools.win.17.0.1.nupkg') 'not used'
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'vsix'
    }

    It 'rejects ambiguous tools packages' {
        Copy-Item $package (Join-Path $modernDev 'microsoft.dynamics.businesscentral.development.tools.17.0.2.nupkg')
        { New-BcCompilerFolder -artifactUrl $artifactUrl } | Should -Throw '*Multiple Development.Tools packages*'
    }

    It 'retains artifact VSIX selection for platforms before 27 even if a tools package is present' {
        $script:platformMajor = 26
        Copy-Item $platform26 (Join-Path $platformArtifact 'ServiceTier\1\Microsoft Dynamics NAV\1\Service\Microsoft.Dynamics.Nav.Ncl.dll') -Force
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'vsix'
    }

    It 'retains Marketplace channel selection for platforms before 27' {
        $script:platformMajor = 26
        Copy-Item $platform26 (Join-Path $platformArtifact 'ServiceTier\1\Microsoft Dynamics NAV\1\Service\Microsoft.Dynamics.Nav.Ncl.dll') -Force
        Mock GetLatestAlLanguageExtensionVersionAndUrl { @('15.1.0', 'https://example.invalid/latest.vsix') }
        Mock Download-File { Set-Content $destinationFile 'vsix' }
        Mock Expand-7zipArchive {
            New-Item -Path (Join-Path $DestinationPath 'extension\bin') -ItemType Directory -Force | Out-Null
            Set-Content (Join-Path $DestinationPath 'extension\bin\alc.dll') 'vsix'
        }
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl -vsixFile preview
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'vsix'
        Should -Invoke GetLatestAlLanguageExtensionVersionAndUrl -Times 1 -Exactly -ParameterFilter { $allowPrerelease }
    }

    It 'preserves explicit VSIX overrides without requiring dotnet or populating the default compiler cache' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'dotnet' }
        $override = Join-Path $root 'override.vsix'
        Set-Content $override 'vsix'
        $cache = Join-Path $root 'cache'
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl -vsixFile $override -cacheFolder $cache
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'vsix'
        Test-Path (Join-Path $cache 'compiler') | Should -BeFalse
    }

    It 'reuses a populated tools cache without downloading artifacts again' {
        $cache = Join-Path $root 'cache'
        $first = New-BcCompilerFolder -artifactUrl $artifactUrl -cacheFolder $cache
        $second = New-BcCompilerFolder -artifactUrl $artifactUrl -cacheFolder $cache
        Get-Content (Join-Path $second 'compiler\extension\bin\alc.dll') | Should -Be 'net8'
        Should -Invoke Download-Artifacts -Times 1 -Exactly
    }

    It 'backfills a compiler cache previously populated with an explicit override' {
        $cache = Join-Path $root 'cache'
        $override = Join-Path $root 'override.vsix'
        Set-Content $override 'vsix'
        $first = New-BcCompilerFolder -artifactUrl $artifactUrl -cacheFolder $cache -vsixFile $override
        $second = New-BcCompilerFolder -artifactUrl $artifactUrl -cacheFolder $cache
        Get-Content (Join-Path $second 'compiler\extension\bin\alc.dll') | Should -Be 'net8'
    }

    It 'resolves <Channel> via NuGet using the platform binary version, not the application URL' -TestCases @(
        @{ Channel = 'latest'; Prerelease = $false }, @{ Channel = 'preview'; Prerelease = $true }
    ) {
        param($Channel, $Prerelease)
        Mock GetDevelopmentToolsPackageInfo { @{ Url = 'https://example.invalid/tools.nupkg'; Headers = @{} } }
        Mock Download-File { Copy-Item $script:package $destinationFile }
        $folder = New-BcCompilerFolder -artifactUrl 'https://example.invalid/sandbox/30.0.1.0/w1' -vsixFile $Channel
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'net8'
        Should -Invoke GetDevelopmentToolsPackageInfo -Times 1 -Exactly -ParameterFilter { $platformVersion.Major -eq 28 -and $allowPrerelease.IsPresent -eq $Prerelease }
        Should -Invoke GetLatestAlLanguageExtensionVersionAndUrl -Times 0
    }

    It 'uses a NuGet channel instead of an existing default compiler cache without overwriting that cache' {
        $cache = Join-Path $root 'cache'
        $first = New-BcCompilerFolder -artifactUrl $artifactUrl -cacheFolder $cache
        Set-Content (Join-Path $cache 'compiler\extension\bin\alc.dll') 'cached default'
        Mock GetDevelopmentToolsPackageInfo { @{ Url = 'https://example.invalid/tools.nupkg'; Headers = @{} } }
        Mock Download-File { Copy-Item $script:package $destinationFile }
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl -cacheFolder $cache -vsixFile latest
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'net8'
        Get-Content (Join-Path $cache 'compiler\extension\bin\alc.dll') | Should -Be 'cached default'
    }

    It 'does not download a newer shared runtime for portable tools targeting installed net8' {
        $script:dotNetRuntimeVersionInstalled = [Version]'8.0.31'
        Mock Download-File { throw 'Unexpected runtime download' }
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl
        Test-Path (Join-Path $folder 'compiler\compiler.runtime.json') | Should -BeTrue
        Should -Invoke Download-File -Times 0
    }

    It 'forwards custom compiler feed settings and authenticates the package download' {
        Mock GetDevelopmentToolsPackageInfo { @{ Url = 'https://feed.example.invalid/tools.nupkg'; Headers = @{ Authorization = 'Basic test-auth' } } }
        Mock Download-File { Copy-Item $script:package $destinationFile }
        $folder = New-BcCompilerFolder -artifactUrl $artifactUrl -vsixFile latest -compilerNuGetServerUrl 'https://feed.example.invalid/index.json' -compilerNuGetToken 'test-token'
        Get-Content (Join-Path $folder 'compiler\extension\bin\alc.dll') | Should -Be 'net8'
        Should -Invoke GetDevelopmentToolsPackageInfo -Times 1 -Exactly -ParameterFilter { $nuGetServerUrl -eq 'https://feed.example.invalid/index.json' -and $nuGetToken -eq 'test-token' }
        Should -Invoke Download-File -Times 1 -Exactly -ParameterFilter { $sourceUrl -eq 'https://feed.example.invalid/tools.nupkg' -and $headers.Authorization -eq 'Basic test-auth' }
    }
}

Describe 'Development tools version precedence' {
    It 'compares <Left> and <Right> with precedence <Expected>' -TestCases @(
        @{ Left = '30.0.0-beta.10'; Right = '30.0.0-beta.9'; Expected = 1 },
        @{ Left = '30.0.0-beta.9'; Right = '30.0.0-beta.10'; Expected = -1 },
        @{ Left = '30.0.0-beta'; Right = '30.0.0-beta.1'; Expected = -1 },
        @{ Left = '30.0.0-1'; Right = '30.0.0-alpha'; Expected = -1 },
        @{ Left = '30.0.0-beta'; Right = '30.0.0-rc'; Expected = -1 },
        @{ Left = '30.0.0-BETA'; Right = '30.0.0-beta'; Expected = 0 },
        @{ Left = '30.0.0'; Right = '30.0.0-beta'; Expected = 1 },
        @{ Left = '30.0.0-beta'; Right = '30.0.0'; Expected = -1 },
        @{ Left = '30.0.0+build2'; Right = '30.0.0+build1'; Expected = 0 },
        @{ Left = '30.0.0.1-beta'; Right = '30.0.0'; Expected = 1 },
        @{ Left = '30.0'; Right = '30.0.0.0'; Expected = 0 },
        @{ Left = '30.0.0-beta.100000000000000000000'; Right = '30.0.0-beta.99999999999999999999'; Expected = 1 }
    ) {
        param($Left, $Right, $Expected)
        [Math]::Sign((CompareDevelopmentToolsPackageVersions $Left $Right)) | Should -Be $Expected
    }
}

Describe 'App metadata DLL invocation' {
    It 'quotes the altool DLL when the compiler folder contains spaces' {
        $folder = Join-Path $TestDrive 'Build Cache'
        $bin = Join-Path $folder 'compiler\extension\bin'
        New-Item $bin -ItemType Directory -Force | Out-Null
        $dll = Join-Path $bin 'altool.dll'
        Set-Content $dll 'fixture'
        $app = Join-Path $folder 'Test App.app'
        Set-Content $app 'fixture'
        Mock CmdDo { '{"id":"test","publisher":"Test","name":"Metadata","version":"1.0.0.0","dependencies":[]}' }
        $info = @(GetAppInfo -appFiles @($app) -compilerFolder $folder)
        $info[0].Name | Should -Be 'Metadata'
        Should -Invoke CmdDo -Times 1 -Exactly -ParameterFilter {
            $Command -eq 'dotnet' -and $arguments -eq """$dll"" GetPackageManifest ""$app"""
        }
    }
}

Describe 'Pipeline compiler channel forwarding' {
    BeforeAll {
        $pipeline = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'AppHandling\Run-AlPipeline.ps1'), [ref]$null, [ref]$null)
        $compilerFunction = $pipeline.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'GetCompilerFolder'
        }, $true)
        . ([scriptblock]::Create($compilerFunction.Extent.Text))
        function Write-PSCallStack {}
    }

    It 'forwards keywords only for compiler-folder builds' {
        Mock GetLatestAlLanguageExtensionVersionAndUrl { @('17.0', 'https://example.invalid/resolved.vsix') }
        DetermineVsixFile -vsixFile latest -useCompilerFolder | Should -Be 'latest'
        DetermineVsixFile -vsixFile preview -useCompilerFolder | Should -Be 'preview'
        Should -Invoke GetLatestAlLanguageExtensionVersionAndUrl -Times 0
        DetermineVsixFile -vsixFile preview | Should -Be 'https://example.invalid/resolved.vsix'
        Should -Invoke GetLatestAlLanguageExtensionVersionAndUrl -Times 1 -Exactly
    }

    It 'passes the compiler feed URL and token to compiler-folder creation' {
        $script:existingCompilerFolder = ''
        $useCompilerFolder = $true
        $artifactUrl = 'https://example.invalid/sandbox/28.0.1.0/w1'
        $artifactCachePath = ''
        $vsixFile = 'latest'
        $containerName = 'test'
        $compilerNuGetServerUrl = 'https://feed.example.invalid/index.json'
        $compilerNuGetToken = 'test-token'
        $NewBcCompilerFolder = {
            param($parameters)
            $parameters.compilerNuGetServerUrl | Should -Be 'https://feed.example.invalid/index.json'
            $parameters.compilerNuGetToken | Should -Be 'test-token'
            $parameters.vsixFile | Should -Be 'latest'
            'compiler-folder'
        }
        GetCompilerFolder | Should -Be 'compiler-folder'
    }
}
}
