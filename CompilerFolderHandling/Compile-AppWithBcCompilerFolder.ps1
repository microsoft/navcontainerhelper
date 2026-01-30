<#
 .Synopsis
  Compile app without docker (used by Run-AlPipeline to compile apps without docker)
 .Description
 .Parameter compilerFolder
  Folder in which compiler and dlls can be found (created by New-BcCompilerFolder)
 .Parameter appProjectFolder
  Location of the project. This folder (or any of its parents) needs to be shared with the container.
 .Parameter appOutputFolder
  Folder in which the output will be placed. This folder (or any of its parents) needs to be shared with the container. Default is $appProjectFolder\output.
 .Parameter appSymbolsFolder
  Folder in which the symbols of dependent apps will be placed. This folder (or any of its parents) needs to be shared with the container. Default is $appProjectFolder\symbols.
 .Parameter appName
  File name of the app. Default is to compose the file name from publisher_appname_version from app.json.
 .Parameter basePath
  Base Path of the files in the ALC output, to convert file paths to relative paths. This folder (or any of its parents) needs to be shared with the container.
 .Parameter UpdateDependencies
  Update the dependency version numbers to the actual version number used during compilation
 .Parameter CopyAppToSymbolsFolder
  Add this switch to copy the compiled app to the appSymbolsFolder.
 .Parameter GenerateReportLayout
  Add this switch to invoke report layout generation during compile. Default is default alc.exe behavior, which is to generate report layout
 .Parameter AzureDevOps
  Add this switch to convert the output to Azure DevOps Build Pipeline compatible output
 .Parameter gitHubActions
  Include this switch to convert the output to GitHub Actions compatible output
 .Parameter EnableCodeCop
  Add this switch to Enable CodeCop to run
 .Parameter EnableAppSourceCop
  Add this switch to Enable AppSourceCop to run
 .Parameter EnablePerTenantExtensionCop
  Add this switch to Enable PerTenantExtensionCop to run
 .Parameter EnableUICop
  Add this switch to Enable UICop to run
 .Parameter RulesetFile
  Specify a ruleset file for the compiler
 .Parameter enableExternalRulesets
  Add this switch to Enable External Rulesets
 .Parameter CustomCodeCops
  Add custom AL code Cops when compiling apps.
 .Parameter Failon
  Specify if you want Compilation to fail on Error or Warning
 .Parameter nowarn
  Specify a nowarn parameter for the compiler
 .Parameter preProcessorSymbols
  PreProcessorSymbols to set when compiling the app.
 .Parameter generatecrossreferences
  Include this flag to generate cross references when compiling
 .Parameter reportSuppressedDiagnostics
  Set reportSuppressedDiagnostics flag on ALC when compiling to ignore pragma warning disables
 .Parameter assemblyProbingPaths
  Specify a comma separated list of paths to include in the search for dotnet assemblies for the compiler
 .Parameter SourceRepositoryUrl
  Repository holding the source code for the app. Will be stamped into the app manifest.
 .Parameter SourceCommit
  The commit identifier for the source code for the app. Will be stamped into the app manifest.
 .Parameter BuildBy
  Information about which product built the app. Will be stamped into the app manifest.
 .Parameter BuildUrl
  The URL for the build job, which built the app. Will be stamped into the app manifest.
 .Parameter OutputTo
  Compiler output is sent to this scriptblock for output. Default value for the scriptblock is: { Param($line) Write-Host $line }
 .Example
  Compile-AppWithBcCompilerFolder -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Project1\Test"
 .Example
  Compile-AppWithBcCompilerFolder -containerName test -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"
 .Example
  Compile-AppWithBcCompilerFolder -containerName test -appProjectFolder "C:\Users\freddyk\Documents\AL\Test" -outputTo { Param($line) if ($line -notlike "*sourcepath=C:\Users\freddyk\Documents\AL\Test\Org\*") { Write-Host $line } }
#>
function Compile-AppWithBcCompilerFolder {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $compilerFolder,
        [Parameter(Mandatory=$true)]
        [string] $appProjectFolder,
        [Parameter(Mandatory=$false)]
        [string] $appOutputFolder = (Join-Path $appProjectFolder "output"),
        [Parameter(Mandatory=$false)]
        [string] $appSymbolsFolder = (Join-Path $appProjectFolder ".alpackages"),
        [Parameter(Mandatory=$false)]
        [string] $appName = "",
        [string] $basePath = "",
        [switch] $UpdateDependencies,
        [switch] $CopyAppToSymbolsFolder,
        [ValidateSet('Yes','No','NotSpecified')]
        [string] $GenerateReportLayout = 'NotSpecified',
        [switch] $AzureDevOps = $bcContainerHelperConfig.IsAzureDevOps,
        [switch] $gitHubActions = $bcContainerHelperConfig.IsGitHubActions,
        [switch] $EnableCodeCop,
        [switch] $EnableAppSourceCop,
        [switch] $EnablePerTenantExtensionCop,
        [switch] $EnableUICop,
        [ValidateSet('none','error','warning','newWarning')]
        [string] $FailOn = 'none',
        [Parameter(Mandatory=$false)]
        [string] $rulesetFile,
        [switch] $generateErrorLog,
        [switch] $enableExternalRulesets,
        [string[]] $CustomCodeCops = @(),
        [Parameter(Mandatory=$false)]
        [string] $nowarn,
        [string[]] $preProcessorSymbols = @(),
        [switch] $GenerateCrossReferences,
        [switch] $ReportSuppressedDiagnostics,
        [Parameter(Mandatory=$false)]
        [string] $assemblyProbingPaths,
        [Parameter(Mandatory=$false)]
        [ValidateSet('ExcludeGeneratedTranslations','GenerateCaptions','GenerateLockedTranslations','NoImplicitWith','TranslationFile','LcgTranslationFile')]
        [string[]] $features = @(),
        [string[]] $treatWarningsAsErrors = $bcContainerHelperConfig.TreatWarningsAsErrors,
        [string] $sourceRepositoryUrl = '',
        [string] $sourceCommit = '',
        [string] $buildBy = "BcContainerHelper,$BcContainerHelperVersion",
        [string] $buildUrl = '',
        [scriptblock] $outputTo = { Param($line) Write-Host $line }
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $startTime = [DateTime]::Now

    if (!(Test-Path $compilerFolder)) {
        throw "CompilerFolder doesn't exist"
    }

    $dllsPath = Join-Path $compilerFolder 'dlls'
    $symbolsPath = Join-Path $compilerFolder 'symbols'

    $appJsonFile = Join-Path $appProjectFolder 'app.json'
    $appJsonObject = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
    if ("$appName" -eq "") {
        $appName = "$($appJsonObject.Publisher)_$($appJsonObject.Name)_$($appJsonObject.Version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
    }
    if ([bool]($appJsonObject.PSobject.Properties.name -eq "id")) {
        AddTelemetryProperty -telemetryScope $telemetryScope -key "id" -value $appJsonObject.id
    }
    elseif ([bool]($appJsonObject.PSobject.Properties.name -eq "appid")) {
        AddTelemetryProperty -telemetryScope $telemetryScope -key "id" -value $appJsonObject.appid
    }
    AddTelemetryProperty -telemetryScope $telemetryScope -key "publisher" -value $appJsonObject.Publisher
    AddTelemetryProperty -telemetryScope $telemetryScope -key "name" -value $appJsonObject.Name
    AddTelemetryProperty -telemetryScope $telemetryScope -key "version" -value $appJsonObject.Version
    AddTelemetryProperty -telemetryScope $telemetryScope -key "appname" -value $appName

    if (!(Test-Path $appOutputFolder -PathType Container)) {
        New-Item $appOutputFolder -ItemType Directory | Out-Null
    }

    Write-Host "Using Symbols Folder: $appSymbolsFolder"
    if (!(Test-Path -Path $appSymbolsFolder -PathType Container)) {
        New-Item -Path $appSymbolsFolder -ItemType Directory | Out-Null
    }

    $dependencies = @()

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "application")) -and $appJsonObject.application) {
        AddTelemetryProperty -telemetryScope $telemetryScope -key "application" -value $appJsonObject.application
        $dependencies += @{"publisher" = ""; "name" = "Application"; "appId" = ''; "version" = $appJsonObject.application }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "platform")) -and $appJsonObject.platform) {
        AddTelemetryProperty -telemetryScope $telemetryScope -key "platform" -value $appJsonObject.platform
        $dependencies += @{"publisher" = "Microsoft"; "name" = "System"; "appId" = '8874ed3a-0643-4247-9ced-7a7002f7135d'; "version" = $appJsonObject.platform }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "dependencies")) -and $appJsonObject.dependencies) {
        $appJsonObject.dependencies | ForEach-Object {
            $dep = $_
            try { $appId = $dep.id } catch { $appId = $dep.appId }
            $dependencies += @{ "publisher" = $dep.publisher; "name" = $dep.name; "appId" = $appId; "version" = $dep.version }
        }
    }

    Write-Host "Enumerating Apps in CompilerFolder $symbolsPath"
    $compilerFolderAppFiles = @(Get-ChildItem -Path (Join-Path $symbolsPath '*.app') | Select-Object -ExpandProperty FullName)
    $compilerFolderApps = @(GetAppInfo -AppFiles $compilerFolderAppFiles -compilerFolder $compilerFolder -cacheAppinfoPath (Join-Path $symbolsPath 'cache_AppInfo.json'))

    Write-Host "Enumerating Apps in Symbols Folder $appSymbolsFolder"
    $existingAppFiles = @(Get-ChildItem -Path (Join-Path $appSymbolsFolder '*.app') | Select-Object -ExpandProperty FullName)
    $existingApps = @(GetAppInfo -AppFiles $existingAppFiles -compilerFolder $compilerFolder -cacheAppinfoPath (Join-Path $appSymbolsFolder 'cache_AppInfo.json'))

    $depidx = 0
    while ($depidx -lt $dependencies.Count) {
        $dependency = $dependencies[$depidx]
        Write-Host "Processing dependency $($dependency.Publisher)_$($dependency.Name)_$($dependency.Version) ($($dependency.AppId))"
        $existingApp = $existingApps | Where-Object {
            if ($dependency.Name -eq 'Application') {
                # For Application package, search by name only (ignore AppId and Publisher)
                ($_.Name -eq $dependency.Name -and ([System.Version]$_.Version -ge [System.Version]$dependency.version))
            } else {
                ((($dependency.appId -ne '' -and $_.AppId -eq $dependency.appId) -or ($dependency.appId -eq '' -and $_.Name -eq $dependency.Name)) -and ([System.Version]$_.Version -ge [System.Version]$dependency.version))
            }
        } | Sort-Object { [System.Version]$_.Version } -Descending | Select-Object -First 1
        $addDependencies = @()
        if ($existingApp) {
            Write-Host "Dependency App exists"
            if ($existingApp.ContainsKey('PropagateDependencies') -and $existingApp.PropagateDependencies -and $existingApp.ContainsKey('Dependencies')) {
                $addDependencies += $existingApp.Dependencies
            }
        }
        else {
            Write-Host "Dependency App not found"
            $copyCompilerFolderApps = @($compilerFolderApps | Where-Object {
                if ($dependency.Name -eq 'Application') {
                    # For Application package, search by name only (ignore AppId and Publisher)
                    ($_.Name -eq $dependency.Name -and ([System.Version]$_.Version -ge [System.Version]$dependency.version))
                } else {
                    ((($dependency.appId -ne '' -and $_.AppId -eq $dependency.appId) -or ($dependency.appId -eq '' -and $_.Name -eq $dependency.Name)) -and ([System.Version]$_.Version -ge [System.Version]$dependency.version))
                }
            })
            $copyCompilerFolderApps | ForEach-Object {
                $copyCompilerFolderApp = $_
                $existingApps += $copyCompilerFolderApp
                Write-Host "Copying $($copyCompilerFolderApp.path) to $appSymbolsFolder"
                Copy-Item -Path $copyCompilerFolderApp.path -Destination $appSymbolsFolder -Force
                if ($copyCompilerFolderApp.Application) {
                    if (!($dependencies | where-Object { $_.Name -eq 'Application'})) {
                        $dependencies += @{"publisher" = ""; "name" = "Application"; "appId" = ''; "version" = $copyCompilerFolderApp.Application }
                    }
                }
                if (!($dependencies | where-Object { ($_.Name -eq "System") -and ($_.Publisher -eq "Microsoft") })) {
                    $dependencies += @{"publisher" = "Microsoft"; "name" = "System"; "appId" = '8874ed3a-0643-4247-9ced-7a7002f7135d'; "version" = $copyCompilerFolderApp.Platform }
                }
                $addDependencies += $copyCompilerFolderApp.Dependencies
            }
        }
        $addDependencies | ForEach-Object {
            $addDependency = $_
            try {
                $appId = $addDependency.id
            }
            catch {
                $appId = $addDependency.appid
            }
            $dependencyExists = $dependencies | Where-Object { $_.appId -eq $appId }
            if (-not $dependencyExists) {
                Write-Host "Adding dependency to $($addDependency.Name) from $($addDependency.Publisher)"
                $dependencies += @($compilerFolderApps | Where-Object { $_.appId -eq $appId })
            }
        }
        $depidx++
    }

        $systemSymbolsApp = @($existingApps | Where-Object { ($_.Name -eq "System") -and ($_.Publisher -eq "Microsoft") })
    if ($systemSymbolsApp.Count -ne 1) {
        throw "Unable to locate system symbols"
    }
    $platformversion = $systemSymbolsApp.Version
    Write-Host "Platform version: $platformversion"

    $GenerateReportLayoutParam = ""
    if (($GenerateReportLayout -ne "NotSpecified") -and ($platformversion.Major -ge 14)) {
        if ($GenerateReportLayout -eq "Yes") {
            $GenerateReportLayoutParam = "/GenerateReportLayout+"
        }
        else {
            $GenerateReportLayoutParam = "/GenerateReportLayout-"
        }
    }

    if ($updateDependencies) {
        $appJsonFile = Join-Path $appProjectFolder 'app.json'
        $appJsonObject = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
        $changes = $false
        Write-Host "Modifying Dependencies"
        if (([bool]($appJsonObject.PSobject.Properties.name -eq "dependencies")) -and $appJsonObject.dependencies) {
            $appJsonObject.dependencies = @($appJsonObject.dependencies | ForEach-Object {
                $dependency = $_
                $dependencyAppId = "$(if ($dependency.PSObject.Properties.name -eq 'AppId') { $dependency.AppId } else { $dependency.Id })"
                Write-Host "Dependency: Id=$dependencyAppId, Publisher=$($dependency.Publisher), Name=$($dependency.Name), Version=$($dependency.Version)"
                $existingApps | Where-Object { $_.AppId -eq [System.Guid]$dependencyAppId -and $_.Version -gt [System.Version]$dependency.Version } | ForEach-Object {
                    $dependency.Version = "$($_.Version)"
                    Write-Host "- Set dependency version to $($_.Version)"
                    $changes = $true
                }
                $dependency
            })
        }
        if (([bool]($appJsonObject.PSobject.Properties.name -eq "application")) -and $appJsonObject.application) {
            Write-Host "Application Dependency $($appJsonObject.application)"
            $existingApps | Where-Object { $_.Name -eq "Application" -and $_.Version -gt [System.Version]$appJsonObject.application } | ForEach-Object {
                $appJsonObject.Application = "$($_.Version)"
                Write-Host "- Set Application dependency to $($_.Version)"
                $changes = $true
            }
        }
        if (([bool]($appJsonObject.PSobject.Properties.name -eq "platform")) -and $appJsonObject.platform) {
            Write-Host "Platform Dependency $($appJsonObject.platform)"
                $existingApps | Where-Object { $_.Name -eq "System" -and $_.Version -gt [System.Version]$appJsonObject.platform -and $_.Publisher -eq "Microsoft"} | ForEach-Object {
                $appJsonObject.platform = "$($_.Version)"
                Write-Host "- Set Platform dependency to $($_.Version)"
                $changes = $true
            }
        }
        if ($changes) {
            Write-Host "Updating app.json"
            $appJsonObject | ConvertTo-Json -depth 99 | Set-Content $appJsonFile -encoding UTF8
        }
    }

    $probingPaths = @()
    if ($assemblyProbingPaths) {
        $probingPaths += @($assemblyProbingPaths)
    }
    $netpackagesPath = Join-Path $appProjectFolder ".netpackages"
    if (Test-Path $netpackagesPath) {
        $probingPaths += @($netpackagesPath)
    }
    if (Test-Path $dllsPath) {
        $probingPaths += @((Join-Path $dllsPath "Service"),(Join-Path $dllsPath "Mock Assemblies"))
    }

    $sharedFolder = Join-Path $dllsPath "shared"
    if (Test-Path $sharedFolder) {
        $probingPaths = @((Join-Path $dllsPath "OpenXML"), $sharedFolder) + $probingPaths
    }
    elseif ($isLinux -or $isMacOS) {
        $probingPaths = @((Join-Path $dllsPath "OpenXML")) + $probingPaths
    }
    elseif ($platformversion.Major -ge 22) {
        if ($dotNetRuntimeVersionInstalled -ge [System.Version]$bcContainerHelperConfig.MinimumDotNetRuntimeVersionStr) {
            $probingPaths = @((Join-Path $dllsPath "OpenXML"), "C:\Program Files\dotnet\shared\Microsoft.NETCore.App\$dotNetRuntimeVersionInstalled", "C:\Program Files\dotnet\shared\Microsoft.AspNetCore.App\$dotNetRuntimeVersionInstalled") + $probingPaths
        }
        else {
            $probingPaths = @((Join-Path $dllsPath "OpenXML")) + $probingPaths
        }
    }
    else {
        $probingPaths = @((Join-Path $dllsPath "OpenXML"), 'C:\Windows\Microsoft.NET\Assembly') + $probingPaths
    }
    $assemblyProbingPaths = $probingPaths -join ','

    $appOutputFile = Join-Path $appOutputFolder $appName
    if (Test-Path -Path $appOutputFile -PathType Leaf) {
        Remove-Item -Path $appOutputFile -Force
    }

    Write-Host "Compiling..."
    $alcParameters = @()
    $binPath = Join-Path $compilerFolder 'compiler/extension/bin'

    $compilerPlatform = 'win32'
    switch ($true) {
        ($isLinux) { $compilerPlatform = 'linux' }
        ($isMacOS) { $compilerPlatform = 'darwin' }
    }
    $alcPath = Join-Path $binPath $compilerPlatform
    if (-not (Test-Path $alcPath)) {
        $alcPath = $binPath
    }

    $alcExe = 'alc.exe'
    $alcCmd = ".\$alcExe"
    if ($isLinux -or $isMacOS) {
        if ($alcPath -eq $binPath) {
            $alcCmd = "dotnet"
            $alcExe = 'alc.dll'
            $alcParameters += @((Join-Path $alcPath $alcExe))
            Write-Host "No $($compilerPlatform) version of alc found. Using dotnet to run alc.dll."
        } else {
            $alcExe = 'alc'
            $alcCmd = "./$alcExe"
        }
    }

    if (!(Test-Path -Path (Join-Path $alcPath $alcExe))) {
        $alcCmd = "dotnet"
        $alcExe = 'alc.dll'
        $alcParameters += @((Join-Path $alcPath $alcExe))
        Write-Host "No alc executable in $compilerPlatform. Using dotnet to run alc.dll."
    }
    $alcItem = Get-Item -Path (Join-Path $alcPath $alcExe)
    [System.Version]$alcVersion = $alcItem.VersionInfo.FileVersion

    $alcParameters += @("/project:""$($appProjectFolder.TrimEnd('/\'))""", "/packagecachepath:""$($appSymbolsFolder.TrimEnd('/\'))""", "/out:""$appOutputFile""")
    if ($GenerateReportLayoutParam) {
        $alcParameters += @($GenerateReportLayoutParam)
    }

    # Microsoft.Dynamics.Nav.Analyzers.Common.dll needs to referenced first, as this is how the analyzers are loaded
    if ($EnableCodeCop -or $EnableAppSourceCop -or $EnablePerTenantExtensionCop -or $EnableUICop) {
        $analyzersCommonDLLPath = Join-Path $binPath 'Analyzers\Microsoft.Dynamics.Nav.Analyzers.Common.dll'
        if (Test-Path $analyzersCommonDLLPath) {
            $alcParameters += @("/analyzer:$(Join-Path $binPath 'Analyzers\Microsoft.Dynamics.Nav.Analyzers.Common.dll')")
        }
    }

    if ($EnableCodeCop) {
        $alcParameters += @("/analyzer:$(Join-Path $binPath 'Analyzers\Microsoft.Dynamics.Nav.CodeCop.dll')")
    }
    if ($EnableAppSourceCop) {
        $alcParameters += @("/analyzer:$(Join-Path $binPath 'Analyzers\Microsoft.Dynamics.Nav.AppSourceCop.dll')")
    }
    if ($EnablePerTenantExtensionCop) {
        $alcParameters += @("/analyzer:$(Join-Path $binPath 'Analyzers\Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll')")
    }
    if ($EnableUICop) {
        $alcParameters += @("/analyzer:$(Join-Path $binPath 'Analyzers\Microsoft.Dynamics.Nav.UICop.dll')")
    }

    if ($CustomCodeCops.Count -gt 0) {
        $CustomCodeCops | ForEach-Object {
            $analyzerFileName = $_
            if ($_ -like 'https://*') {
                $analyzerFileName = Join-Path $binPath "Analyzers/$(Split-Path $_ -Leaf)"
                Download-File -SourceUrl $_ -destinationFile $analyzerFileName
            }
            $alcParameters += @("/analyzer:$analyzerFileName")
        }
    }

    if ($rulesetFile) {
        $alcParameters += @("/ruleset:$rulesetfile")
    }

    if ($enableExternalRulesets) {
        $alcParameters += @("/enableexternalrulesets")
    }

    if ($nowarn) {
        $alcParameters += @("/nowarn:$nowarn")
    }

    if ($generateErrorLog) {
        $errorLogFilePath = $appOutputFile -replace '.app$', '.errorLog.json'
        $alcParameters += @("/errorLog:""$errorLogFilePath""")
    }

    if ($GenerateCrossReferences -and $platformversion.Major -ge 18) {
        $alcParameters += @("/generatecrossreferences")
    }

    if ($ReportSuppressedDiagnostics) {
        if ($alcVersion -ge [System.Version]"9.1.0.0") {
            $alcParameters += @("/reportsuppresseddiagnostics")
        }
        else {
            Write-Host -ForegroundColor Yellow "ReportSuppressedDiagnostics was specified, but the version of the AL Language Extension does not support this. Get-LatestAlLanguageExtensionUrl returns a location for the latest AL Language Extension"
        }
    }

    if ($alcVersion -ge [System.Version]"12.0.12.41479") {
        if ($sourceRepositoryUrl) {
            $alcParameters += @("/SourceRepositoryUrl:$sourceRepositoryUrl")
        }
        if ($sourceCommit) {
            $alcParameters += @("/SourceCommit:$sourceCommit")
        }
        if ($buildBy) {
            $alcParameters += @("/BuildBy:$buildBy")
        }
        if ($buildUrl) {
            $alcParameters += @("/BuildUrl:$buildUrl")
        }
    }

    if ($assemblyProbingPaths) {
        $alcParameters += @("/assemblyprobingpaths:$assemblyProbingPaths")
    }

    if ($features) {
        $alcParameters +=@("/features:$($features -join ',')")
    }

    $preprocessorSymbols | where-Object { $_ } | ForEach-Object { $alcParameters += @("/D:$_") }

    Push-Location -Path $alcPath
    try {
        Write-Host "$alcCmd $([string]::Join(' ', $alcParameters))"
        $result = & $alcCmd $alcParameters
    }
    finally {
        Pop-Location
    }

    if ($lastexitcode -ne 0 -and $lastexitcode -ne -1073740791) {
        "App generation failed with exit code $lastexitcode"
    }

    if ($treatWarningsAsErrors) {
        $regexp = ($treatWarningsAsErrors | ForEach-Object { if ($_ -eq '*') { ".*" } else { $_ } }) -join '|'
        $result = $result | ForEach-Object { $_ -replace "^(.*)warning ($regexp):(.*)`$", '$1error $2:$3' }
    }

    $devOpsResult = ""
    if ($result) {
        $Parameters = @{
            "FailOn"           = $FailOn
            "AlcOutput"        = $result
            "DoNotWriteToHost" = $true
        }
        if ($gitHubActions) {
            $Parameters += @{
                "gitHubActions" = $true
            }
            if (-not $basePath) {
                $basePath = $ENV:GITHUB_WORKSPACE
            }
        }
        if ($basePath) {
            $Parameters += @{
                "basePath" = $basePath
            }
        }
        $devOpsResult = Convert-ALCOutputToAzureDevOps @Parameters
    }
    if ($AzureDevOps -or $gitHubActions) {
        $devOpsResult | ForEach-Object { $outputTo.Invoke($_) }
    }
    else {
        $result | ForEach-Object { $outputTo.Invoke($_) }
        if ($devOpsResult -like "*task.complete result=Failed*") {
            throw "App generation failed"
        }
    }

    $result | Where-Object { $_ -like "App generation failed*" } | ForEach-Object { throw $_ }

    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
    $appFile = Join-Path $appOutputFolder $appName

    if (Test-Path -Path $appFile) {
        Write-Host "$appFile successfully created in $timespend seconds"
        if ($CopyAppToSymbolsFolder) {
            Copy-Item -Path $appFile -Destination $appSymbolsFolder -ErrorAction SilentlyContinue
        }
    }
    else {
        throw "App generation failed"
    }
    $appFile
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Compile-AppWithBcCompilerFolder
