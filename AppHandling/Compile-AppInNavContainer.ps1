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
 .Parameter UpdateSymbols
  Add this switch to indicate that you want to force the download of symbols for all dependent apps.
 .Parameter AzureDevOps
  Add this switch to convert the output to Azure DevOps Build Pipeline compatible output
 .Parameter EnableCodeCop
  Add this switch to Enable CodeCop to run
 .Parameter RulesetFile
  Specify a ruleset file for the compiler.
 .Parameter Failon
  Specify if you want Compilation to fail on Error or Warning (Works only if you specify -AzureDevOps)
 .Example
  Compile-AppInNavContainer -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"
 .Example
  Compile-AppInNavContainer -containerName test -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"

#>
function Compile-AppInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$credential = $null,
        [Parameter(Mandatory=$true)]
        [string]$appProjectFolder,
        [Parameter(Mandatory=$false)]
        [string]$appOutputFolder = (Join-Path $appProjectFolder "output"),
        [Parameter(Mandatory=$false)]
        [string]$appSymbolsFolder = (Join-Path $appProjectFolder ".alpackages"),
        [switch]$UpdateSymbols,
        [switch]$AzureDevOps,
        [switch]$EnableCodeCop,
        [ValidateSet('none','error','warning')]
        [string]$FailOn = 'none',
        [Parameter(Mandatory=$false)]
        [string]$rulesetFile,
        [Parameter(Mandatory=$false)]
        [string]$nowarn,
        [Parameter(Mandatory=$false)]
        [string]$assemblyProbingPaths
    )

    $startTime = [DateTime]::Now

    $platform = Get-NavContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-NavContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform
    
    $containerProjectFolder = Get-NavContainerPath -containerName $containerName -path $appProjectFolder
    if ("$containerProjectFolder" -eq "") {
        throw "The appProjectFolder ($appProjectFolder) is not shared with the container."
    }

    if (!$PSBoundParameters.ContainsKey("assemblyProbingPaths")) {
        if ($platformversion.Major -ge 13) {
            $assemblyProbingPaths = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appProjectFolder)
                $assemblyProbingPaths = ""
                $netpackagesPath = Join-Path $appProjectFolder ".netpackages"
                $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
                $roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
                if (Test-Path $netpackagesPath) {
                    $assemblyProbingPaths += """$netpackagesPath"","
                }
                $assemblyProbingPaths += """$roleTailoredClientFolder"",""$serviceTierFolder"",""C:\Program Files (x86)\Open XML SDK\V2.5\lib"",""c:\windows\assembly"""
                $assemblyProbingPaths
            } -ArgumentList $containerProjectFolder
        }
    }

    $containerOutputFolder = Get-NavContainerPath -containerName $containerName -path $appOutputFolder
    if ("$containerOutputFolder" -eq "") {
        throw "The appOutputFolder ($appOutputFolder) is not shared with the container."
    }

    $containerSymbolsFolder = Get-NavContainerPath -containerName $containerName -path $appSymbolsFolder
    if ("$containerSymbolsFolder" -eq "") {
        throw "The appSymbolsFolder ($appSymbolsFolder) is not shared with the container."
    }

    $containerRulesetFile = ""
    if ($rulesetFile) {
        $containerRulesetFile = Get-NavContainerPath -containerName $containerName -path $rulesetFile
        if ("$containerRulesetFile" -eq "") {
            throw "The rulesetFile ($rulesetFile) is not shared with the container."
        }
    }

    if (!(Test-Path $appOutputFolder -PathType Container)) {
        New-Item $appOutputFolder -ItemType Directory | Out-Null
    }

    $appJsonFile = Join-Path $appProjectFolder 'app.json'
    $appJsonObject = Get-Content -Raw -Path $appJsonFile | ConvertFrom-Json
    $appName = "$($appJsonObject.Publisher)_$($appJsonObject.Name)_$($appJsonObject.Version).app"

    Write-Host "Using Symbols Folder: $appSymbolsFolder"
    if (!(Test-Path -Path $appSymbolsFolder -PathType Container)) {
        New-Item -Path $appSymbolsFolder -ItemType Directory | Out-Null
    }

    $customConfig = Get-NavContainerServerConfiguration -ContainerName $containerName

    $dependencies = @()

    if (([bool]($appJsonObject.PSobject.Properties.name -match "application")) -and $appJsonObject.application)
    {
        $dependencies += @{"publisher" = "Microsoft"; "name" = "Application"; "version" = $appJsonObject.application }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -match "platform")) -and $appJsonObject.platform)
    {
        $dependencies += @{"publisher" = "Microsoft"; "name" = "System"; "version" = $appJsonObject.platform }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -match "test")) -and $appJsonObject.test)
    {
        $dependencies +=  @{"publisher" = "Microsoft"; "name" = "Test"; "version" = $appJsonObject.test }
        if (([bool]($customConfig.PSobject.Properties.name -match "EnableSymbolLoadingAtServerStartup")) -and ($customConfig.EnableSymbolLoadingAtServerStartup -eq "true")) {
            throw "app.json should NOT have a test dependency when running hybrid development (EnableSymbolLoading)"
        }
    }

    if (([bool]($appJsonObject.PSobject.Properties.name -match "dependencies")) -and $appJsonObject.dependencies)
    {
        $appJsonObject.dependencies | ForEach-Object {
            $dependencies += @{ "publisher" = $_.publisher; "name" = $_.name; "version" = $_.version }
        }
    }

    if (!$updateSymbols) {
        $existingApps = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appSymbolsFolder)
            Get-ChildItem -Path (Join-Path $appSymbolsFolder '*.app') | ForEach-Object { Get-NavAppInfo -Path $_.FullName }
        } -ArgumentList $containerSymbolsFolder
    }
    $publishedApps = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($tenant)
        Get-NavAppInfo -ServerInstance $ServerInstance -tenant $tenant
        Get-NavAppInfo -ServerInstance $ServerInstance -symbolsOnly
    } -ArgumentList $tenant | Where-Object { $_ -isnot [System.String] }

    $applicationApp = $publishedApps | Where-Object { $_.publisher -eq "Microsoft" -and $_.name -eq "Application" }
    if (-not $applicationApp) {
        # locate application version number in database if using SQLEXPRESS
        try {
            if (($customConfig.DatabaseServer -eq "localhost") -and ($customConfig.DatabaseInstance -eq "SQLEXPRESS")) {
                $appVersion = Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param($databaseName)
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

    $ip = Get-NavContainerIpAddress -containerName $containerName
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
    

    $authParam = @{}
    if ($customConfig.ClientServicesCredentialType -eq "Windows") {
        $authParam += @{ "usedefaultcredential" = $true }
    }
    else {
        if (!($credential)) {
            throw "You need to specify credentials when you are not using Windows Authentication"
        }
        
        $pair = ("$($Credential.UserName):"+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"
        $headers = @{ Authorization = $basicAuthValue }
        $authParam += @{ "headers" = $headers }
    }

    $dependencies | ForEach-Object {
        $dependency = $_
        if ($updateSymbols -or !($existingApps | Where-Object {($_.Name -eq $dependency.name) -and ($_.Publisher -eq $dependency.publisher)})) {
            $publisher = $_.publisher
            $name = $_.name
            $version = $_.version
            $symbolsName = "$($publisher)_$($name)_$($version).app"
            $publishedApps | Where-Object { $_.publisher -eq $publisher -and $_.name -eq $name } | % {
                $symbolsName = "$($publisher)_$($name)_$($_.version).app"
            }
            $symbolsFile = Join-Path $appSymbolsFolder $symbolsName
            Write-Host "Downloading symbols: $symbolsName"

            $publisher = [uri]::EscapeDataString($publisher)
            $url = "$devServerUrl/dev/packages?publisher=$($publisher)&appName=$($name)&versionText=$($version)&tenant=$tenant"
            Write-Host "Url : $Url"
            Invoke-RestMethod -Method Get -Uri $url @AuthParam -OutFile $symbolsFile
        }
    }

    if ($sslverificationdisabled) {
        Write-Host "Re-enabling SSL Verification"
        [SslVerification]::Enable()
    }

    $result = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appProjectFolder, $appSymbolsFolder, $appOutputFile, $EnableCodeCop, $rulesetFile, $assemblyProbingPaths, $nowarn )

        if (!(Test-Path "c:\build" -PathType Container)) {
            $tempZip = Join-Path $env:TEMP "alc.zip"
            Copy-item -Path (Get-Item -Path "c:\run\*.vsix").FullName -Destination $tempZip
            Expand-Archive -Path $tempZip -DestinationPath "c:\build\vsix"
        }
        $alcPath = 'C:\build\vsix\extension\bin'

        if (Test-Path -Path $appOutputFile -PathType Leaf) {
            Remove-Item -Path $appOutputFile -Force
        }

        Write-Host "Compiling..."
        Set-Location -Path $alcPath

        $alcParameters = @("/project:$appProjectFolder", "/packagecachepath:$appSymbolsFolder", "/out:$appOutputFile")
        
        if ($EnableCodeCop) {
            $analyzerPath = Join-Path $alcPath "Analyzers\Microsoft.Dynamics.Nav.CodeCop.dll"
            $alcParameters += @("/analyzer:$analyzerPath")
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

        Write-Host "alc.exe $([string]::Join(' ', $alcParameters))"

        & .\alc.exe $alcParameters

    } -ArgumentList $containerProjectFolder, $containerSymbolsFolder, (Join-Path $containerOutputFolder $appName), $EnableCodeCop, $containerRulesetFile, $assemblyProbingPaths, $nowarn
    
    if ($AzureDevOps) {
        $result | Convert-ALCOutputToAzureDevOps -FailOn $FailOn
    }
    else {
        $result | Write-Host
    }

    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
    $appFile = Join-Path $appOutputFolder $appName

    if (Test-Path -Path $appFile) {
        Write-Host "$appFile successfully created in $timespend seconds"
    }
    else {
        Write-Error "App generation failed"
    }
    $appFile
}
Set-Alias -Name Compile-AppInBCContainer -Value Compile-AppInNavContainer
Export-ModuleMember -Function Compile-AppInNavContainer -Alias Compile-AppInBCContainer
