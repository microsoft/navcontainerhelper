<# 
 .Synopsis
  Use Nav Container to Compile App
 .Description
 .Parameter containerName
  Name of the container which you want to use to compile the app
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter credential
  Credentials of the NAV SUPER user if using NavUserPassword authentication
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
        [string]$FailOn = 'none'
    )

    $startTime = [DateTime]::Now

    $containerProjectFolder = Get-NavContainerPath -containerName $containerName -path $appProjectFolder
    if ("$containerProjectFolder" -eq "") {
        throw "The appProjectFolder ($appProjectFolder) is not shared with the container."
    }

    $containerOutputFolder = Get-NavContainerPath -containerName $containerName -path $appOutputFolder
    if ("$containerOutputFolder" -eq "") {
        throw "The appOutputFolder ($appOutputFolder) is not shared with the container."
    }

    $containerSymbolsFolder = Get-NavContainerPath -containerName $containerName -path $appSymbolsFolder
    if ("$containerSymbolsFolder" -eq "") {
        throw "The appSymbolsFolder ($appSymbolsFolder) is not shared with the container."
    }

    if (!(Test-Path $appOutputFolder -PathType Container)) {
        New-Item $appOutputFolder -ItemType Directory | Out-Null
    }

    $appJsonFile = Join-Path $appProjectFolder 'app.json'
    $appJsonObject = Get-Content -Raw -Path $appJsonFile | ConvertFrom-Json
    $appName = "$($appJsonObject.Publisher)_$($appJsonObject.Name)_$($appJsonObject.Version).app"
    $appFile = Join-Path $appOutputFolder $appName
    if (Test-Path -Path $appFile -PathType Leaf) {
        Remove-Item -Path $appFile -Force
    }

    $result = Invoke-ScriptInNavContainer -containerName $containerName { Param($tenant, $credential, $appProjectFolder, $appOutputFolder, $appOutputFile, $appSymbolsFolder, $UpdateSymbols, $AzureDevOps, $EnableCodeCop, $FailOn)

        $ErrorActionPreference = "Stop"

        $appJsonFile = Join-Path $appProjectFolder 'app.json'
        $appJsonObject = Get-Content -Raw -Path $appJsonFile | ConvertFrom-Json

        Write-Host "Using Symbols Folder: $appSymbolsFolder"
        if (!(Test-Path -Path $appSymbolsFolder -PathType Container)) {
            New-Item -Path $appSymbolsFolder -ItemType Directory | Out-Null
        }

        $customConfig = @{}
        (Get-NAVServerInstance -ServerInstance NAV | Get-NAVServerConfiguration -AsXml).configuration.appSettings.add | ForEach-Object{
            $customConfig | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }

        $dependencies = @(
            @{"publisher" = "Microsoft"; "name" = "Application"; "version" = $appJsonObject.application }
            @{"publisher" = "Microsoft"; "name" = "System"; "version" = $appJsonObject.platform }
        )

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
            $existingApps = Get-ChildItem -Path (Join-Path $appSymbolsFolder '*.app') | ForEach-Object { Get-NavAppInfo -Path $_.FullName }
        }
        $publishedApps = Get-NavAppInfo -ServerInstance NAV -tenant $tenant
        $publishedApps += Get-NavAppInfo -ServerInstance NAV -symbolsOnly

        $applicationApp = $publishedApps | Where-Object { $_.publisher -eq "Microsoft" -and $_.name -eq "Application" }
        if (-not $applicationApp) {
            # locate application version number in database if using SQLEXPRESS
            try {
                if (($customConfig.DatabaseServer -eq "localhost") -and ($customConfig.DatabaseInstance -eq "SQLEXPRESS")) {
                    $appVersion = (invoke-sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -ErrorAction Stop -Query "SELECT [applicationversion] FROM [$($customConfig.DatabaseName)].[dbo].[`$ndo`$dbproperty]").applicationVersion
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
                [SslVerification]::Disable()
            }

        }
        else {
            $protocol = "http://"
        }
        $devServerUrl = "$($protocol)localhost:$($customConfig.DeveloperServicesPort)/$ServerInstance"

        $authParam = @{}
        if ($credential) {
            if ($customConfig.ClientServicesCredentialType -eq "Windows") {
                Throw "You should not specify credentials when using Windows Authentication"
            }
            $pair = ("$($Credential.UserName):"+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
            $base64 = [System.Convert]::ToBase64String($bytes)
            $basicAuthValue = "Basic $base64"
            $headers = @{ Authorization = $basicAuthValue }
            $authParam += @{"headers" = $headers}
        } else {
            if ($customConfig.ClientServicesCredentialType -ne "Windows") {
                Throw "You need to specify credentials when you are not using Windows Authentication"
            }
            $authParam += @{"usedefaultcredential" = $true}
        }

        $dependencies | ForEach-Object {
            $dependency = $_
            if ($updateSymbols -or !($existingApps | Where-Object {($_.Name -eq $dependency.name) -and ($_.Publisher -eq $dependency.publisher)})) {
                $publisher = $_.publisher
                $name = $_.name
                $version = $_.version
                $symbolsName = "${publisher}_${name}_${version}.app"
                $publishedApps | Where-Object { $_.publisher -eq $publisher -and $_.name -eq $name } | % {
                    $symbolsName = "${publisher}_${name}_$($_.version).app"
                }
                $symbolsFile = Join-Path $appSymbolsFolder $symbolsName
                Write-Host "Downloading symbols: $symbolsName"

                $publisher = [uri]::EscapeDataString($publisher)
                $url = "$devServerUrl/dev/packages?publisher=${publisher}&appName=${name}&versionText=${version}&tenant=$tenant"
                Write-Host "Url : $Url"
                Invoke-RestMethod -Method Get -Uri $url @AuthParam -OutFile $symbolsFile
            }
        }

        if (!(Test-Path "c:\build" -PathType Container)) {
            $tempZip = Join-Path $env:TEMP "alc.zip"
            Copy-item -Path (Get-Item -Path "c:\run\*.vsix").FullName -Destination $tempZip
            Expand-Archive -Path $tempZip -DestinationPath "c:\build\vsix"
        }

        $alcPath = 'C:\build\vsix\extension\bin'
        $analyzerPath = 'C:\build\vsix\extension\bin\Analyzers\Microsoft.Dynamics.Nav.CodeCop.dll'

        Write-Host "Compiling..."
        Set-Location -Path $alcPath
        if ($EnableCodeCop) {
            & .\alc.exe /project:$appProjectFolder /packagecachepath:$appSymbolsFolder /out:$appOutputFile /analyzer:$analyzerPath
        } else {
            & .\alc.exe /project:$appProjectFolder /packagecachepath:$appSymbolsFolder /out:$appOutputFile
        }

    } -argumentList $tenant, $credential, $containerProjectFolder, $containerOutputFolder, (Get-NavContainerPath -containerName $containerName -path $appFile), $containerSymbolsFolder, $UpdateSymbols, $AzureDevOps, $EnableCodeCop, $FailOn

    if ($AzureDevOps) {
        $result | Convert-ALCOutputToAzureDevOps -FailOn $FailOn
    } else {
        $result | Write-Host
    }

    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)

    if (Test-Path -Path $appFile) {
        Write-Host "$appFile successfully created in $timespend seconds"
    } else {
        Write-Error "App generation failed"
    }
    $appFile
}
Export-ModuleMember -Function Compile-AppInNavContainer
