<#
 .Synopsis
  Use NAV/BC Container to Compile App
 .Description
 .Parameter containerName
  Name of the container in which you want to use to compile the app
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter credential
  Credentials of the SUPER user if using NavUserPassword authentication
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
 .Parameter UpdateSymbols
  Add this switch to indicate that you want to force the download of symbols for all dependent apps.
 .Parameter UpdateDependencies
  Update the dependency version numbers to the actual version number used during compilation
 .Parameter CopySymbolsFromContainer
  Add this switch to copy system and base application symbols from container to speed up symbol download.
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
 .Parameter generateErrorLog
  Switch parameter on whether to generate an alerts log file. Default is false.
  The file will be placed in the same folder as the app file, and will have the same name as the app file, but with the extension .errorLog.json.
 .Parameter preProcessorSymbols
  PreProcessorSymbols to set when compiling the app.
 .Parameter generatecrossreferences
  Include this flag to generate cross references when compiling
 .Parameter reportSuppressedDiagnostics
  Set reportSuppressedDiagnostics flag on ALC when compiling to ignore pragma warning disables
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the compile function will use the online Business Central Environment as target for the compilation
 .Parameter environment
  Environment to use for the compilation.
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
  Compile-AppInBcContainer -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"
 .Example
  Compile-AppInBcContainer -containerName test -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"
 .Example
  Compile-AppInBcContainer -containerName test -appProjectFolder "C:\Users\freddyk\Documents\AL\Test" -outputTo { Param($line) if ($line -notlike "*sourcepath=C:\Users\freddyk\Documents\AL\Test\Org\*") { Write-Host $line } }
#>
function Compile-AppInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [Parameter(Mandatory=$true)]
        [string] $appProjectFolder,
        [Parameter(Mandatory=$false)]
        [string] $appOutputFolder = (Join-Path $appProjectFolder "output"),
        [Parameter(Mandatory=$false)]
        [string] $appSymbolsFolder = (Join-Path $appProjectFolder ".alpackages"),
        [Parameter(Mandatory=$false)]
        [string] $appName = "",
        [string] $basePath = "",
        [switch] $UpdateSymbols,
        [switch] $UpdateDependencies,
        [switch] $CopySymbolsFromContainer,
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
        [switch] $enableExternalRulesets,
        [string[]] $CustomCodeCops = @(),
        [Parameter(Mandatory=$false)]
        [string] $nowarn,
        [switch] $generateErrorLog,
        [string[]] $preProcessorSymbols = @(),
        [switch] $GenerateCrossReferences,
        [switch] $ReportSuppressedDiagnostics,
        [Parameter(Mandatory=$false)]
        [string] $assemblyProbingPaths,
        [Parameter(Mandatory=$false)]
        [ValidateSet('ExcludeGeneratedTranslations','GenerateCaptions','GenerateLockedTranslations','NoImplicitWith','TranslationFile','LcgTranslationFile')]
        [string[]] $features = @(),
        [Hashtable] $bcAuthContext,
        [string] $environment,
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

    $platform = Get-BcContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-BcContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform

    $containerProjectFolder = Get-BcContainerPath -containerName $containerName -path $appProjectFolder
    if ("$containerProjectFolder" -eq "") {
        throw "The appProjectFolder ($appProjectFolder) is not shared with the container."
    }

    $containerFolder = Get-BcContainerPath -containerName $containerName -path (Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName")
    if (!$PSBoundParameters.ContainsKey("assemblyProbingPaths")) {
        if ($platformversion.Major -ge 13) {
            $assemblyProbingPaths = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($containerFolder, $appProjectFolder, $platformVersion)
                $assemblyProbingPaths = ""
                $netpackagesPath = Join-Path $appProjectFolder ".netpackages"
                if (Test-Path $netpackagesPath) {
                    $assemblyProbingPaths += """$netpackagesPath"","
                }

                $roleTailoredClientFolder = "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client"
                if (Test-Path $roleTailoredClientFolder) {
                    $assemblyProbingPaths += """$((Get-Item $roleTailoredClientFolder).FullName)"","
                }

                $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
                if ($platformversion.Major -ge 22) {
                    $dotnetAssembliesFolder = Join-Path $containerFolder ".netPackages\Service"
                    if (!(Test-Path $dotnetAssembliesFolder)) {
                        New-Item $dotnetAssembliesFolder -ItemType Directory -Force | Out-Null

                        Write-Host "Copying DLLs from $serviceTierFolder to assemblyProbingPath"
                        Copy-Item -Path $serviceTierFolder -filter '*.dll' -Destination $dotnetAssembliesFolder -Recurse -Force -ErrorAction SilentlyContinue

                        $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
                        Copy-Item -Path $mockAssembliesPath -filter '*.dll' -Destination $dotnetAssembliesFolder -Recurse -Force -ErrorAction SilentlyContinue

                        Write-Host "Removing dotnet Framework Assemblies"
                        $dotnetServiceFolder = Join-Path $dotnetAssembliesFolder "Service"
                        Remove-Item -Path (Join-Path $dotnetserviceFolder 'Management') -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path (Join-Path $dotnetserviceFolder 'SideServices') -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path (Join-Path $dotnetserviceFolder 'WindowsServiceInstaller') -Recurse -Force -ErrorAction SilentlyContinue
                    }

                    $assemblyProbingPaths += """$dotnetAssembliesFolder"""
                    $assemblyProbingPaths = """C:\Program Files\dotnet\shared"",$assemblyProbingPaths"
                }
                else {
                    $assemblyProbingPaths += """$serviceTierFolder"",""C:\Program Files (x86)\Open XML SDK\V2.5\lib"""
                    $assemblyProbingPaths += ',"c:\Windows\Microsoft.NET\Assembly"'
                    $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
                    if (Test-Path $mockAssembliesPath -PathType Container) {
                        $assemblyProbingPaths += ",""$mockAssembliesPath"""
                    }
                }
                $assemblyProbingPaths
            } -ArgumentList $containerFolder, $containerProjectFolder, $platformversion
        }
    }

    $containerOutputFolder = Get-BcContainerPath -containerName $containerName -path $appOutputFolder
    if ("$containerOutputFolder" -eq "") {
        throw "The appOutputFolder ($appOutputFolder) is not shared with the container."
    }

    $containerSymbolsFolder = Get-BcContainerPath -containerName $containerName -path $appSymbolsFolder
    if ("$containerSymbolsFolder" -eq "") {
        throw "The appSymbolsFolder ($appSymbolsFolder) is not shared with the container."
    }

    $containerRulesetFile = ""
    if ($rulesetFile) {
        $containerRulesetFile = Get-BcContainerPath -containerName $containerName -path $rulesetFile
        if ("$containerRulesetFile" -eq "") {
            throw "The rulesetFile ($rulesetFile) is not shared with the container."
        }
    }

    $CustomCodeCopFiles = @()
    if ($CustomCodeCops.Count -gt 0) {
        $CustomCodeCops | ForEach-Object {
            if ($_ -like 'https://*') {
                $customCopPath = $_
            }
            else {
                $customCopPath = Get-BcContainerPath -containerName $containerName -path $_
                if ("$customCopPath" -eq "") {
                    throw "The custom code cop ($_) is not shared with the container."
                }
            }
            $CustomCodeCopFiles += $customCopPath
        }
    }

    if (!(Test-Path $appOutputFolder -PathType Container)) {
        New-Item $appOutputFolder -ItemType Directory | Out-Null
    }

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

    Write-Host "Using Symbols Folder: $appSymbolsFolder"
    if (!(Test-Path -Path $appSymbolsFolder -PathType Container)) {
        New-Item -Path $appSymbolsFolder -ItemType Directory | Out-Null
    }

    if ($CopySymbolsFromContainer) {
        CopySymbolsFromContainer -containerName $containerName -containerSymbolsFolder $containerSymbolsFolder
    }

    $GenerateReportLayoutParam = ""
    if (($GenerateReportLayout -ne "NotSpecified") -and ($platformversion.Major -ge 14)) {
        if ($GenerateReportLayout -eq "Yes") {
            $GenerateReportLayoutParam = "/GenerateReportLayout+"
        }
        else {
            $GenerateReportLayoutParam = "/GenerateReportLayout-"
        }
    }

    # unpack compiler
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock {
        if (!(Test-Path "c:\build" -PathType Container)) {
            $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "alc.zip"
            Copy-item -Path (Get-Item -Path "c:\run\*.vsix").FullName -Destination $tempZip
            Expand-Archive -Path $tempZip -DestinationPath "c:\build\vsix"
        }
    }

    $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName

    $dependencies = @()

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "application")) -and $appJsonObject.application) {
        AddTelemetryProperty -telemetryScope $telemetryScope -key "application" -value $appJsonObject.application
        $dependencies += @{"publisher" = "Microsoft"; "name" = "Application"; "appId" = 'c1335042-3002-4257-bf8a-75c898ccb1b8'; "version" = $appJsonObject.application }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "platform")) -and $appJsonObject.platform) {
        AddTelemetryProperty -telemetryScope $telemetryScope -key "platform" -value $appJsonObject.platform
        $dependencies += @{"publisher" = "Microsoft"; "name" = "System"; "appId" = '8874ed3a-0643-4247-9ced-7a7002f7135d'; "version" = $appJsonObject.platform }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "test")) -and $appJsonObject.test) {
        $dependencies +=  @{"publisher" = "Microsoft"; "name" = "Test"; "appId" = ''; "version" = $appJsonObject.test }
        if (([bool]($customConfig.PSobject.Properties.name -eq "EnableSymbolLoadingAtServerStartup")) -and ($customConfig.EnableSymbolLoadingAtServerStartup -eq "true")) {
            throw "app.json should NOT have a test dependency when running hybrid development (EnableSymbolLoading)"
        }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "dependencies")) -and $appJsonObject.dependencies) {
        $appJsonObject.dependencies | ForEach-Object {
            $dep = $_
            try { $appId = $dep.id } catch { $appId = $dep.appId }
            $dependencies += @{ "publisher" = $dep.publisher; "name" = $dep.name; "appId" = $appId; "version" = $dep.version }
        }
    }

    $existingApps = @()
    if (!$updateSymbols) {
        $existingApps = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appSymbolsFolder)
            Get-ChildItem -Path (Join-Path $appSymbolsFolder '*.app') | ForEach-Object {
                $alcPath = 'C:\build\vsix\extension\bin'
                $alToolExe = Join-Path $alcPath 'win32\altool.exe'
                $alToolExists = Test-Path -Path $alToolExe -PathType Leaf
                if ($alToolExists) {
                    $manifest = & "$alToolExe" GetPackageManifest "$($_.FullName)" | ConvertFrom-Json
                    $dependencies = @()
                    $propagateDependencies = $false
                    if ($manifest.PSObject.Properties.Name -eq 'dependencies') {
                        $dependencies = @($manifest.dependencies | ForEach-Object { @{ "Publisher" = $_.publisher; "Name" = $_.name; "Version" = $_.version; "AppId" = $_.id } })
                    }
                    if ($manifest.PSObject.Properties.Name -eq 'propagateDependencies') {
                        $propagateDependencies = $manifest.propagateDependencies
                    }
                    return @{ "AppId" = $manifest.id; "Publisher" = $manifest.publisher; "Name" = $manifest.name; "Version" = $manifest.version; "PropagateDependencies" = $propagateDependencies; "Dependencies" = $dependencies }
                }
                else {
                    $appInfo = Get-NavAppInfo -Path $_.FullName
                    return @{ "AppId" = $appInfo.AppId; "Publisher" = $appInfo.publisher; "Name" = $appInfo.name; "Version" = $appInfo.version; "PropagateDependencies" = $false; "Dependencies" = @() }
                }
            }
        } -ArgumentList $containerSymbolsFolder
    }
    $publishedApps = @()
    if ($customConfig.ServerInstance) {
        $publishedApps = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($tenant)
            Get-NavAppInfo -ServerInstance $ServerInstance -tenant $tenant
            Get-NavAppInfo -ServerInstance $ServerInstance -symbolsOnly -ErrorAction SilentlyContinue
        } -ArgumentList $tenant | Where-Object { $_ -isnot [System.String] }
    }

    $applicationApp = $publishedApps | Where-Object { $_.publisher -eq "Microsoft" -and $_.name -eq "Application" }
    if ((-not $applicationApp) -and ($platformversion -le [System.Version]"26.0.0.0")) {
        # locate application version number in database if using SQLEXPRESS
        try {
            if (($customConfig.DatabaseServer -eq "localhost") -and ($customConfig.DatabaseInstance -eq "SQLEXPRESS")) {
                $appVersion = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($databaseName)
                    (invoke-sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -ErrorAction Stop -Query "SELECT [applicationversion] FROM [$databaseName].[dbo].[`$ndo`$dbproperty]").applicationVersion
                } -argumentList $customConfig.DatabaseName
                $publishedApps += @{ "Name" = "Application"; "Publisher" = "Microsoft"; "Version" = $appversion }
            }
        }
        catch {
            # ignore errors - use version number in app.json
        }
    }

    $sslVerificationDisabled = $false
    $serverInstance = $customConfig.ServerInstance
    $headers = @{}
    $useDefaultCredentials = $false
    $timeout = 100
    if ($bcAuthContext -and $environment) {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bcEnvironment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.Name -eq $environment -and $_.Type -eq "Sandbox" }
        if (!$bcEnvironment) {
            throw "Environment $environment doesn't exist in the current context or it is not a Sandbox environment."
        }
        $publishedApps = Get-BcPublishedApps -bcAuthContext $bcAuthContext -environment $environment | Where-Object { $_.state -eq "installed" }
        $devServerUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment"
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers."Authorization" = $bearerAuthValue
    }
    elseif ($serverInstance -eq "") {
        if ($updateSymbols) {
            Write-Host -ForegroundColor Yellow "INFO: You have to specify AuthContext and Environment if you are compiling in a filesOnly container in order to download dependencies"
        }
        $devServerUrl = ""
    }
    else {
        if ($customConfig.DeveloperServicesSSLEnabled -eq "true") {
            $protocol = "https://"
        }
        else {
            $protocol = "http://"
        }

        $ip = Get-BcContainerIpAddress -containerName $containerName
        if ($ip) {
            $devServerUrl = "$($protocol)$($ip):$($customConfig.DeveloperServicesPort)/$ServerInstance"
        }
        else {
            $devServerUrl = "$($protocol)$($containerName):$($customConfig.DeveloperServicesPort)/$ServerInstance"
        }

        $timeout = 300000
        $sslVerificationDisabled = ($protocol -eq "https://")
        if ($customConfig.ClientServicesCredentialType -eq "Windows") {
            $useDefaultCredentials = $true
        }
        else {
            if (!($credential)) {
                throw "You need to specify credentials when you are not using Windows Authentication"
            }

            $pair = ("$($Credential.UserName):"+[System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
            $base64 = [System.Convert]::ToBase64String($bytes)
            $basicAuthValue = "Basic $base64"
            $headers."Authorization" = $basicAuthValue
        }
    }

    $depidx = 0
    while ($depidx -lt $dependencies.Count) {
        $dependency = $dependencies[$depidx]
        Write-Host "Processing dependency $($dependency.Publisher)_$($dependency.Name)_$($dependency.Version) ($($dependency.AppId))"
        $existingApp = $existingApps | Where-Object {
            if ($platformversion -ge [System.Version]"19.0.0.0") {
                ((($dependency.appId -ne '' -and $_.AppId.ToString() -eq $dependency.appId) -or ($dependency.appId -eq '' -and $_.Name -eq $dependency.Name)) -and ([System.Version]$_.Version -ge [System.Version]$dependency.version))
            }
            else {
                (($_.Name -eq $dependency.name) -and ($_.Name -eq "Application" -or (($_.Publisher -eq $dependency.publisher) -and ([System.Version]$_.Version -ge [System.Version]$dependency.version))))
            }
        } | Sort-Object { [System.Version]$_.Version } -Descending | Select-Object -First 1
        $addDependencies = @()
        if ($existingApp) {
            Write-Host "Dependency App exists"
            if ($existingApp.ContainsKey('PropagateDependencies') -and $existingApp.PropagateDependencies -and $existingApp.ContainsKey('Dependencies')) {
                $addDependencies += $existingApp.Dependencies
            }
        }
        if ($updateSymbols -or !$existingApp) {
            $publisher = $dependency.publisher
            $name = $dependency.name
            $appId = $dependency.appId
            $version = $dependency.version
            $symbolsName = "$($publisher)_$($name)_$($version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
            $publishedApps | Where-Object { $_.publisher -eq $publisher -and $_.name -eq $name } | ForEach-Object {
                $symbolsName = "$($publisher)_$($name)_$($_.version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
            }
            if (($devServerUrl -eq "") -or ($headers -eq @{} -and !$useDefaultCredentials)) {
                Write-Host -ForegroundColor Yellow "WARNING: Unable to download symbols for $symbolsName"
            }
            else {
                $symbolsFile = Join-Path $appSymbolsFolder $symbolsName
                Write-Host "Downloading symbols: $symbolsName"

                $publisher = [uri]::EscapeDataString($publisher)
                $name = [uri]::EscapeDataString($name)
                if ($appId -and $platformversion -ge [System.Version]"20.0.0.0") {
                    $url = "$devServerUrl/dev/packages?appId=$($appId)&versionText=$($version)&tenant=$tenant"
                }
                else {
                    $url = "$devServerUrl/dev/packages?publisher=$($publisher)&appName=$($name)&versionText=$($version)&tenant=$tenant"
                }
                Write-Host "Url : $Url"
                try {
                    DownloadFileLow -sourceUrl $url -destinationFile $symbolsFile -timeout $timeout -useDefaultCredentials:$useDefaultCredentials -Headers $headers -skipCertificateCheck:$sslVerificationDisabled
                }
                catch {
                    $throw = $true
                    if ($customConfig.ServerInstance -ne '' -and $customConfig.ClientServicesCredentialType -eq "Windows") {
                        try {
                            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($url, $symbolsFile)
                                $webClient = [System.Net.WebClient]::new()
                                $webClient.UseDefaultCredentials = $true
                                $webClient.DownloadFile($url, $symbolsFile)
                            } -argumentList $url, (Get-BcContainerPath -containerName $containerName -path $symbolsFile)
                            $throw = $false
                        }
                        catch {
                        }
                    }
                    if ($throw) {
                        throw "Error downloading symbols for $symbolsName. Error was: $($_.Exception.Message)"
                    }
                }
                if (Test-Path -Path $symbolsFile) {
                    $addDependencies = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($symbolsFile, $platformversion)
                        # Wait for file to be accessible in container
                        While (-not (Test-Path $symbolsFile)) { Start-Sleep -Milliseconds 100 }

                        if ($platformversion.Major -ge 15) {
                            Add-Type -AssemblyName System.IO.Compression.FileSystem
                            Add-Type -AssemblyName System.Text.Encoding

                            try {
                                # Import types needed to invoke the compiler
                                $alcPath = 'C:\build\vsix\extension\bin'
                                $alToolExe = Join-Path $alcPath 'win32\altool.exe'
                                $alToolExists = Test-Path -Path $alToolExe -PathType Leaf
                                if ($alToolExists) {
                                    $manifest = & "$alToolExe" GetPackageManifest "$symbolsFile" | ConvertFrom-Json
                                    if ($manifest.PSObject.Properties.Name -eq 'application' -and $manifest.application) {
                                        @{ "publisher" = "Microsoft"; "name" = "Application"; "appId" = 'c1335042-3002-4257-bf8a-75c898ccb1b8'; "version" = $manifest.Application }
                                    }
                                    if ($manifest.PSObject.Properties.Name -eq 'dependencies') {
                                        foreach ($dependency in $manifest.dependencies) {
                                            @{ "publisher" = $dependency.Publisher; "name" = $dependency.name; "appId" = $dependency.id; "Version" = $dependency.Version }
                                        }
                                    }
                                }
                                else {
                                    Add-Type -Path (Join-Path $alcPath Newtonsoft.Json.dll)
                                    Add-Type -Path (Join-Path $alcPath System.Collections.Immutable.dll)
                                    if (Test-Path (Join-Path $alcPath System.IO.Packaging.dll)) {
                                        Add-Type -Path (Join-Path $alcPath System.IO.Packaging.dll)
                                    }
                                    Add-Type -Path (Join-Path $alcPath Microsoft.Dynamics.Nav.CodeAnalysis.dll)

                                    $packageStream = [System.IO.File]::OpenRead($symbolsFile)
                                    $package = [Microsoft.Dynamics.Nav.CodeAnalysis.Packaging.NavAppPackageReader]::Create($PackageStream, $true)
                                    $manifest = $package.ReadNavAppManifest()

                                    if ($manifest.application) {
                                        @{ "publisher" = "Microsoft"; "name" = "Application"; "appId" = 'c1335042-3002-4257-bf8a-75c898ccb1b8'; "version" = $manifest.Application }
                                    }

                                    foreach ($dependency in $manifest.dependencies) {
                                        $appId = ''
                                        if ($dependency.psobject.Properties.name -eq 'appid') {
                                            $appId = $dependency.appid
                                        }
                                        elseif ($dependency.psobject.Properties.name -eq 'id') {
                                            $appId = $dependency.id
                                        }
                                        @{ "publisher" = $dependency.Publisher; "name" = $dependency.name; "appId" = $appId; "Version" = $dependency.Version }
                                    }
                                }
                            }
                            catch [System.Reflection.ReflectionTypeLoadException] {
                                if ($_.Exception.LoaderExceptions) {
                                    $_.Exception.LoaderExceptions | ForEach-Object {
                                        Write-Host "LoaderException: $($_.Message)"
                                    }
                                }
                                throw
                            }
                            finally {
                                if ($package) {
                                    $package.Dispose()
                                }
                                if ($packageStream) {
                                    $packageStream.Dispose()
                                }
                            }
                        }
                    } -ArgumentList (Get-BcContainerPath -containerName $containerName -path $symbolsFile), $platformversion
                }
            }
        }
        $addDependencies | ForEach-Object {
            $addDependency = $_
            $found = $false
            $dependencies | ForEach-Object {
                if ((($_.appId) -and ($_.appId -eq $addDependency.appId)) -or ($_.Publisher -eq $addDependency.Publisher -and $_.Name -eq $addDependency.Name)) {
                    $found = $true
                }
            }
            if (!$found) {
                Write-Host "Adding dependency to $($addDependency.Name) from $($addDependency.Publisher)"
                $dependencies += $addDependency
            }
        }
        $depidx++
    }

    $errorLogFilePath = ""
    if($generateErrorLog) {
        $errorLogFilePath = (Join-Path $containerOutputFolder $($appName -replace '.app$','.errorLog.json'))
    }

    $result = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appProjectFolder, $appSymbolsFolder, $appOutputFile, $EnableCodeCop, $EnableAppSourceCop, $EnablePerTenantExtensionCop, $EnableUICop, $CustomCodeCops, $rulesetFile, $enableExternalRulesets, $assemblyProbingPaths, $nowarn, $errorLogFilePath, $GenerateCrossReferences, $ReportSuppressedDiagnostics, $generateReportLayoutParam, $features, $preProcessorSymbols, $platformversion, $updateDependencies, $sourceRepositoryUrl, $sourceCommit, $buildBy, $buildUrl )

        if ($updateDependencies) {
            $appJsonFile = Join-Path $appProjectFolder 'app.json'
            $appJsonObject = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
            $changes = $false
            Write-Host "Enumerating Existing Apps"
            $existingApps = Get-ChildItem -Path (Join-Path $appSymbolsFolder '*.app') | ForEach-Object {
                $appInfo = Get-NavAppInfo -Path $_.FullName
                Write-Host "- FileName=$($_.Name), Id=$($appInfo.AppId), Publisher=$($appInfo.Publisher), Name=$($appInfo.Name), Version=$($appInfo.Version)"
                $appInfo
            }
            Write-Host "Modifying Dependencies"
            if (([bool]($appJsonObject.PSobject.Properties.name -eq "dependencies")) -and $appJsonObject.dependencies) {
                $appJsonObject.dependencies = @($appJsonObject.dependencies | ForEach-Object {
                    $dependency = $_
                    $dependencyAppId = "$(if ($dependency.PSObject.Properties.name -eq 'AppId') { $dependency.AppId } else { $dependency.Id })"
                    Write-Host "Dependency: Id=$dependencyAppId, Publisher=$($dependency.Publisher), Name=$($dependency.Name), Version=$($dependency.Version)"
                    $existingApps | Where-Object { "$($_.AppId)" -eq $dependencyAppId -and $_.Version -gt [System.Version]$dependency.Version } | ForEach-Object {
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
                $existingApps | Where-Object { $_.Name -eq "System" -and $_.Version -gt [System.Version]$appJsonObject.platform } | ForEach-Object {
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

        $binPath = 'C:\build\vsix\extension\bin'
        $alcPath = Join-Path $binPath 'win32'
        if (-not (Test-Path $alcPath)) {
            $alcPath = $binPath
        }

        if (Test-Path -Path $appOutputFile -PathType Leaf) {
            Remove-Item -Path $appOutputFile -Force
        }

        Write-Host "Compiling..."
        Set-Location -Path $alcPath

        $alcItem = Get-Item -Path (Join-Path $alcPath 'alc.exe')
        [System.Version]$alcVersion = $alcItem.VersionInfo.FileVersion

        $alcParameters = @("/project:""$($appProjectFolder.TrimEnd('/\'))""", "/packagecachepath:""$($appSymbolsFolder.TrimEnd('/\'))""", "/out:""$appOutputFile""")
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

        if ($errorLogFilePath) {
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

        Write-Host ".\alc.exe $([string]::Join(' ', $alcParameters))"

        & .\alc.exe $alcParameters

        if ($lastexitcode -ne 0 -and $lastexitcode -ne -1073740791) {
            "App generation failed with exit code $lastexitcode"
        }
    } -ArgumentList $containerProjectFolder, $containerSymbolsFolder, (Join-Path $containerOutputFolder $appName), $EnableCodeCop, $EnableAppSourceCop, $EnablePerTenantExtensionCop, $EnableUICop, $CustomCodeCopFiles, $containerRulesetFile, $enableExternalRulesets, $assemblyProbingPaths, $nowarn, $errorLogFilePath, $GenerateCrossReferences, $ReportSuppressedDiagnostics, $GenerateReportLayoutParam, $features, $preProcessorSymbols, $platformversion, $updateDependencies, $sourceRepositoryUrl, $sourceCommit, $buildBy, $buildUrl

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
                "basePath" = (Get-BcContainerPath -containerName $containerName -path $basePath)
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
            if (Test-Path -Path (Join-Path -Path $appSymbolsFolder -ChildPath $appName)) {
                Write-Host "$($appName) copied to $($appSymbolsFolder)"
                Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appSymbolsFolder, $appName)
                    $appFile = Join-Path -Path $appSymbolsFolder -ChildPath $appName
                    while (-not (Test-Path -Path $appFile)) { Start-Sleep -Seconds 1 }
                } -ArgumentList $containerSymbolsFolder,"$($appName)"
            }
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
Set-Alias -Name Compile-AppInNavContainer -Value Compile-AppInBcContainer
Export-ModuleMember -Function Compile-AppInBcContainer -Alias Compile-AppInNavContainer
