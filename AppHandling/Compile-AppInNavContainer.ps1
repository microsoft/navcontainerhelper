<# 
 .Synopsis
  Use NAV/BC Container to Compile App
 .Description
 .Parameter containerName
  Name of the container which you want to use to compile the app
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
 .Parameter UpdateSymbols
  Add this switch to indicate that you want to force the download of symbols for all dependent apps.
 .Parameter CopyAppToSymbolsFolder
  Add this switch to copy the compiled app to the appSymbolsFolder.
 .Parameter GenerateReportLayout
  Add this switch to invoke report layout generation during compile. Default is default alc.exe behavior, which is to generate report layout
 .Parameter AzureDevOps
  Add this switch to convert the output to Azure DevOps Build Pipeline compatible output
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
 .Parameter Failon
  Specify if you want Compilation to fail on Error or Warning (Works only if you specify -AzureDevOps)
 .Parameter nowarn
  Specify a nowarn parameter for the compiler
 .Parameter assemblyProbingPaths
  Specify a comma separated list of paths to include in the search for dotnet assemblies for the compiler
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
        [switch] $UpdateSymbols,
        [switch] $CopyAppToSymbolsFolder,
        [ValidateSet('Yes','No','NotSpecified')]
        [string] $GenerateReportLayout = 'NotSpecified',
        [switch] $AzureDevOps,
        [switch] $EnableCodeCop,
        [switch] $EnableAppSourceCop,
        [switch] $EnablePerTenantExtensionCop,
        [switch] $EnableUICop,
        [ValidateSet('none','error','warning')]
        [string] $FailOn = 'none',
        [Parameter(Mandatory=$false)]
        [string] $rulesetFile,
        [Parameter(Mandatory=$false)]
        [string] $nowarn,
        [Parameter(Mandatory=$false)]
        [string] $assemblyProbingPaths,
        [scriptblock] $outputTo = { Param($line) Write-Host $line }
    )

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

    if (!$PSBoundParameters.ContainsKey("assemblyProbingPaths")) {
        if ($platformversion.Major -ge 13) {
            $assemblyProbingPaths = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appProjectFolder)
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
                $assemblyProbingPaths += """$serviceTierFolder"",""C:\Program Files (x86)\Open XML SDK\V2.5\lib"",""c:\Windows\Microsoft.NET\Assembly"""
                $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
                if (Test-Path $mockAssembliesPath -PathType Container) {
                    $assemblyProbingPaths += ",""$mockAssembliesPath"""
                }


                $assemblyProbingPaths
            } -ArgumentList $containerProjectFolder
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

    if (!(Test-Path $appOutputFolder -PathType Container)) {
        New-Item $appOutputFolder -ItemType Directory | Out-Null
    }

    $appJsonFile = Join-Path $appProjectFolder 'app.json'
    $appJsonObject = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
    if ("$appName" -eq "") {
        $appName = "$($appJsonObject.Publisher)_$($appJsonObject.Name)_$($appJsonObject.Version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
    }

    Write-Host "Using Symbols Folder: $appSymbolsFolder"
    if (!(Test-Path -Path $appSymbolsFolder -PathType Container)) {
        New-Item -Path $appSymbolsFolder -ItemType Directory | Out-Null
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
            $tempZip = Join-Path $env:TEMP "alc.zip"
            Copy-item -Path (Get-Item -Path "c:\run\*.vsix").FullName -Destination $tempZip
            Expand-Archive -Path $tempZip -DestinationPath "c:\build\vsix"
        }
    }

    $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName

    $dependencies = @()

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "application")) -and $appJsonObject.application)
    {
        $dependencies += @{"publisher" = "Microsoft"; "name" = "Application"; "version" = $appJsonObject.application }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "platform")) -and $appJsonObject.platform)
    {
        $dependencies += @{"publisher" = "Microsoft"; "name" = "System"; "version" = $appJsonObject.platform }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "test")) -and $appJsonObject.test)
    {
        $dependencies +=  @{"publisher" = "Microsoft"; "name" = "Test"; "version" = $appJsonObject.test }
        if (([bool]($customConfig.PSobject.Properties.name -eq "EnableSymbolLoadingAtServerStartup")) -and ($customConfig.EnableSymbolLoadingAtServerStartup -eq "true")) {
            throw "app.json should NOT have a test dependency when running hybrid development (EnableSymbolLoading)"
        }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -eq "dependencies")) -and $appJsonObject.dependencies)
    {
        $appJsonObject.dependencies | ForEach-Object {
            $dependencies += @{ "publisher" = $_.publisher; "name" = $_.name; "version" = $_.version }
        }
    }

    if (!$updateSymbols) {
        $existingApps = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appSymbolsFolder)
            Get-ChildItem -Path (Join-Path $appSymbolsFolder '*.app') | ForEach-Object { Get-NavAppInfo -Path $_.FullName }
        } -ArgumentList $containerSymbolsFolder
    }
    $publishedApps = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($tenant)
        Get-NavAppInfo -ServerInstance $ServerInstance -tenant $tenant
        Get-NavAppInfo -ServerInstance $ServerInstance -symbolsOnly
    } -ArgumentList $tenant | Where-Object { $_ -isnot [System.String] }

    $applicationApp = $publishedApps | Where-Object { $_.publisher -eq "Microsoft" -and $_.name -eq "Application" }
    if (-not $applicationApp) {
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

    $serverInstance = $customConfig.ServerInstance
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

    $sslVerificationDisabled = ($protocol -eq "https://")
    if ($sslVerificationDisabled) {
        if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type)
        {
            Add-Type -TypeDefinition "
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public static class SslVerification
                {
                    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
                    public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
                    public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
                }"
        }
        Write-Host "Disabling SSL Verification"
        [SslVerification]::Disable()
    }

    $webClient = [TimeoutWebClient]::new(300000)
    if ($customConfig.ClientServicesCredentialType -eq "Windows") {
        $webClient.UseDefaultCredentials = $true
    }
    else {
        if (!($credential)) {
            throw "You need to specify credentials when you are not using Windows Authentication"
        }
        
        $pair = ("$($Credential.UserName):"+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"
        $webClient.Headers.Add("Authorization", $basicAuthValue)
    }

    $depidx = 0
    while ($depidx -lt $dependencies.Count) {
        $dependency = $dependencies[$depidx]
        if ($updateSymbols -or !($existingApps | Where-Object {($_.Name -eq $dependency.name) -and ($_.Name -eq "Application" -or $_.Publisher -eq $dependency.publisher)})) {
            $publisher = $dependency.publisher
            $name = $dependency.name
            $version = $dependency.version
            $symbolsName = "$($publisher)_$($name)_$($version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
            $publishedApps | Where-Object { $_.publisher -eq $publisher -and $_.name -eq $name } | % {
                $symbolsName = "$($publisher)_$($name)_$($_.version).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
            }
            $symbolsFile = Join-Path $appSymbolsFolder $symbolsName
            Write-Host "Downloading symbols: $symbolsName"

            $publisher = [uri]::EscapeDataString($publisher)
            $url = "$devServerUrl/dev/packages?publisher=$($publisher)&appName=$($name)&versionText=$($version)&tenant=$tenant"
            Write-Host "Url : $Url"
            $webClient.DownloadFile($url, $symbolsFile)
            if (Test-Path -Path $symbolsFile) {
                $addDependencies = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($symbolsFile, $platformversion)
                    # Wait for file to be accessible in container
                    While (-not (Test-Path $symbolsFile)) { Start-Sleep -Seconds 1 }

                    if ($platformversion.Major -ge 15) {
                        $alcPath = 'C:\build\vsix\extension\bin'
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        Add-Type -AssemblyName System.Text.Encoding
        
                        # Import types needed to invoke the compiler
                        Add-Type -Path (Join-Path $alcPath System.Collections.Immutable.dll)
                        Add-Type -Path (Join-Path $alcPath Microsoft.Dynamics.Nav.CodeAnalysis.dll)
    
                        try {
                            $packageStream = [System.IO.File]::OpenRead($symbolsFile)
                            $package = [Microsoft.Dynamics.Nav.CodeAnalysis.Packaging.NavAppPackageReader]::Create($PackageStream, $true)
                            $manifest = $package.ReadNavAppManifest()
        
                            if ($manifest.application) {
                                @{ "publisher" = "Microsoft"; "name" = "Application"; "version" = $manifest.Application }
                            }
        
                            foreach ($dependency in $manifest.dependencies) {
                                @{ "publisher" = $dependency.Publisher; "name" = $dependency.name; "Version" = $dependency.Version }
                            }
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

                $addDependencies | % {
                    $addDependency = $_
                    $found = $false
                    $dependencies | % {
                        if ($_.Publisher -eq $addDependency.Publisher -and $_.Name -eq $addDependency.Name) {
                            $found = $true
                        }
                    }
                    if (!$found) {
                        Write-Host "Adding dependency to $($addDependency.Name) from $($addDependency.Publisher)"
                        $dependencies += $addDependency
                    }
                }
            }
        }
        $depidx++
    }
 
    if ($sslverificationdisabled) {
        Write-Host "Re-enabling SSL Verification"
        [SslVerification]::Enable()
    }

    $result = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appProjectFolder, $appSymbolsFolder, $appOutputFile, $EnableCodeCop, $EnableAppSourceCop, $EnablePerTenantExtensionCop, $EnableUICop, $rulesetFile, $assemblyProbingPaths, $nowarn, $generateReportLayoutParam )

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

        $alcParameters = @("/project:""$($appProjectFolder.TrimEnd('/\'))""", "/packagecachepath:""$($appSymbolsFolder.TrimEnd('/\'))""", "/out:""$appOutputFile""")
        if ($GenerateReportLayoutParam) {
            $alcParameters += @($GenerateReportLayoutParam)
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

        if ($rulesetFile) {
            $alcParameters += @("/ruleset:$rulesetfile")
        }

        if ($nowarn) {
            $alcParameters += @("/nowarn:$nowarn")
        }

        if ($assemblyProbingPaths) {
            $alcParameters += @("/assemblyprobingpaths:$assemblyProbingPaths")
        }

        Write-Host ".\alc.exe $([string]::Join(' ', $alcParameters))"

        & .\alc.exe $alcParameters

    } -ArgumentList $containerProjectFolder, $containerSymbolsFolder, (Join-Path $containerOutputFolder $appName), $EnableCodeCop, $EnableAppSourceCop, $EnablePerTenantExtensionCop, $EnableUICop, $containerRulesetFile, $assemblyProbingPaths, $nowarn, $GenerateReportLayoutParam
    
    if ($AzureDevOps) {
        if ($result) {
            $result = Convert-ALCOutputToAzureDevOps -FailOn $FailOn -AlcOutput $result -DoNotWriteToHost
        }
    }
    $result | % { $outputTo.Invoke($_) }

    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
    $appFile = Join-Path $appOutputFolder $appName

    if (Test-Path -Path $appFile) {
        Write-Host "$appFile successfully created in $timespend seconds"
        if ($CopyAppToSymbolsFolder) {
            Copy-Item -Path $appFile -Destination $appSymbolsFolder -ErrorAction SilentlyContinue
            if (Test-Path -Path (Join-Path -Path $appSymbolsFolder -ChildPath $appName)) {
                Write-Host "${appName} copied to ${appSymbolsFolder}"
            }
        }
    }
    else {
        Write-Error "App generation failed"
    }
    $appFile
}
Set-Alias -Name Compile-AppInNavContainer -Value Compile-AppInBcContainer
Export-ModuleMember -Function Compile-AppInBcContainer -Alias Compile-AppInNavContainer
