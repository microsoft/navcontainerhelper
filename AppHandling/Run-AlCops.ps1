<#
 .Synopsis
  Run AL Cops
 .Description
  Run AL Cops
 .Parameter containerName
  Name of the validation container. Default is bcserver.
 .Parameter credential
  These are the credentials used for the container. If not provided, the Run-AlValidation function will generate a random password and use that.
 .Parameter previousApps
  Array or comma separated list of previous version of apps to use for AppSourceCop validation and upgrade test
 .Parameter apps
  Array or comma separated list of apps to validate
 .Parameter affixes
  Array or comma separated list of affixes to use for AppSourceCop validation
 .Parameter supportedCountries
  Array or comma separated list of supportedCountries to use for AppSourceCop validation
 .Parameter obsoleteTagMinAllowedMajorMinor
  Objects that are pending obsoletion with an obsolete tag version lower than the minimum set in the AppSourceCop.json file are not allowed. (AS0105)
 .Parameter appPackagesFolder
  Folder in which symbols and apps will be cached. The folder must be shared with the container.
 .Parameter enableAppSourceCop
  Include this switch to enable AppSource Cop
 .Parameter enableCodeCop
  Include this switch to enable Code Cop
 .Parameter enableUICop
  Include this switch to enable UI Cop
 .Parameter enablePerTenantExtensionCop
  Include this switch to enable Per Tenant Extension Cop
 .Parameter failOnError
  Include this switch if you want to fail on the first error instead of returning all errors to the caller
 .Parameter ignoreWarnings
  Include this switch if you want to ignore Warnings
 .Parameter doNotIgnoreInfos
  Include this switch if you don't want to ignore Infos
 .Parameter rulesetFile
  Filename of the ruleset file for Compile-AppInBcContainer
 .Parameter skipVerification
  Include this parameter to skip verification of code signing certificate. Note that you cannot request Microsoft to set this parameter when validating for AppSource.
 .Parameter reportSuppressedDiagnostics
  Set reportSuppressedDiagnostics flag on ALC when compiling to ignore pragma warning disables
 .Parameter CompileAppInBcContainer
  Override function parameter for Compile-AppInBcContainer
#>
function Run-AlCops {
    Param(
        $containerName = $bcContainerHelperConfig.defaultContainerName,
        [PSCredential] $credential,
        $previousApps,
        $apps,
        $affixes,
        $supportedCountries,
        [string] $obsoleteTagMinAllowedMajorMinor = "",
        $appPackagesFolder = (Join-Path $bcContainerHelperConfig.hostHelperFolder ([Guid]::NewGuid().ToString())),
        [switch] $enableAppSourceCop,
        [switch] $enableCodeCop,
        [switch] $enableUICop,
        [switch] $enablePerTenantExtensionCop,
        [switch] $failOnError,
        [switch] $ignoreWarnings,
        [switch] $doNotIgnoreInfos,
        [switch] $reportsuppresseddiagnostics = $true,
        [switch] $skipVerification,
        [string] $rulesetFile = "",
        [scriptblock] $CompileAppInBcContainer
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        if ($previousApps -is [String]) { $previousApps = @($previousApps.Split(',').Trim() | Where-Object { $_ }) }
        if ($apps -is [String]) { $apps = @($apps.Split(',').Trim()  | Where-Object { $_ }) }
        if ($affixes -is [String]) { $affixes = @($affixes.Split(',').Trim() | Where-Object { $_ }) }
        if ($supportedCountries -is [String]) { $supportedCountries = @($supportedCountries.Split(',').Trim() | Where-Object { $_ }) }
        $supportedCountries = $supportedCountries | Where-Object { $_ } | ForEach-Object { getCountryCode -countryCode $_ }

        if ($CompileAppInBcContainer) {
            Write-Host -ForegroundColor Yellow "CompileAppInBcContainer override"; Write-Host $CompileAppInBcContainer.ToString()
        }
        else {
            $CompileAppInBcContainer = { Param([Hashtable]$parameters) Compile-AppInBcContainer @parameters }
        }

        if ($enableAppSourceCop -and $enablePerTenantExtensionCop) {
            throw "You cannot run AppSourceCop and PerTenantExtensionCop at the same time"
        }

        $appsFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder ([Guid]::NewGuid().ToString())
        New-Item -Path $appsFolder -ItemType Directory | Out-Null
        $apps = Sort-AppFilesByDependencies -containerName $containerName -appFiles @(CopyAppFilesToFolder -appFiles $apps -folder $appsFolder) -WarningAction SilentlyContinue

        $appPackFolderCreated = $false
        if (!(Test-Path $appPackagesFolder)) {
            New-Item -Path $appPackagesFolder -ItemType Directory | Out-Null
            $appPackFolderCreated = $true
        }

        $previousAppVersions = @{}
        if ($enableAppSourceCop -and $previousApps) {
            Write-Host "Copying previous apps to packages folder"
            $appList = CopyAppFilesToFolder -appFiles $previousApps -folder $appPackagesFolder
            $previousApps = Sort-AppFilesByDependencies -containerName $containerName -appFiles $appList -WarningAction SilentlyContinue
            $previousApps | ForEach-Object {
                $appFile = $_
                $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
                try {
                    Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson
                    $xappJsonFile = Join-Path $tmpFolder "app.json"
                    $xappJson = [System.IO.File]::ReadAllLines($xappJsonFile) | ConvertFrom-Json
                    Write-Host "$($xappJson.Publisher)_$($xappJson.Name) = $($xappJson.Version)"
                    $previousAppVersions += @{ "$($xappJson.Publisher)_$($xappJson.Name)" = $xappJson.Version }
                }
                catch {
                    throw "Cannot use previous app $([System.IO.Path]::GetFileName($appFile)), it might be a runtime package."
                }
                finally {
                    if (Test-Path $tmpFolder) {
                        Remove-Item $tmpFolder -Recurse -Force
                    }
                }
            }
        }

        $artifactUrl = Get-BcContainerArtifactUrl -containerName $containerName
        $artifactVersion = [System.Version]$artifactUrl.Split('/')[4]
        $latestSupportedRuntimeVersion = RunAlTool -arguments @('GetLatestSupportedRuntimeVersion',"$($artifactVersion.Major).$($artifactVersion.Minor)")
        Write-Host "Latest Supported Runtime Version: $latestSupportedRuntimeVersion"

        $global:_validationResult = @()
        $apps | ForEach-Object {
            $appFile = $_
            $appFileName = [System.IO.Path]::GetFileName($appFile)

            $tmpFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder ([Guid]::NewGuid().ToString())
            try {
                $length = $global:_validationResult.Length
                if (!$skipVerification) {
                    Copy-Item -path $appFile -Destination "$tmpFolder.app"
                    $signResult = Invoke-ScriptInBcContainer -containerName $containerName -scriptBlock { Param($appTmpFile)
                        if (!(Test-Path "C:\Windows\System32\vcruntime140_1.dll")) {
                            Write-Host "Downloading vcredist_x64 (version 140)"
                            (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/vs/17/release/vc_redist.x64.exe', 'c:\run\install\vcredist_x64-140.exe')
                            Write-Host "Installing vcredist_x64 (version 140)"
                            start-process -Wait -FilePath c:\run\install\vcredist_x64-140.exe -ArgumentList /q, /norestart
                        }
                        Get-AuthenticodeSignature -FilePath $appTmpFile
                    } -argumentList (Get-BcContainerPath -containerName $containerName -path "$tmpFolder.app")
                    Remove-Item "$tmpFolder.app" -Force

                    if ($signResult.Status.Value -eq "valid") {
                        Write-Host -ForegroundColor Green "$appFileName is Signed with $($signResult.SignatureType.Value) certificate: $($signResult.SignerCertificate.Subject)"
                    }
                    else {
                        Write-Host -ForegroundColor Red "$appFileName is not signed, result is $($signResult.Status.Value)"
                        $global:_validationResult += @("$appFileName is not signed, result is $($signResult.Status.Value)")
                    }
                }

                Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson -excludeRuntimeProperty -latestSupportedRuntimeVersion $latestSupportedRuntimeVersion
                $appJson = [System.IO.File]::ReadAllLines((Join-Path $tmpFolder "app.json")) | ConvertFrom-Json

                $ruleset = $null

                if ("$rulesetFile" -ne "" -or $enableAppSourceCop) {
                    $ruleset = [ordered]@{
                        "name"             = "Run-AlCops RuleSet"
                        "description"      = "Generated by Run-AlCops"
                        "includedRuleSets" = @()
                    }
                }

                if ($rulesetFile) {
                    $customRulesetFile = Join-Path $tmpFolder "custom.ruleset.json"
                    Copy-Item -Path $rulesetFile -Destination $customRulesetFile
                    $ruleset.includedRuleSets += @(@{
                            "action" = "Default"
                            "path"   = Get-BcContainerPath -containerName $containerName -path $customRulesetFile
                        })
                }

                if ($enableAppSourceCop) {
                    Write-Host "Analyzing: $appFileName"
                    Write-Host "Using affixes: $([string]::Join(',',$affixes))"
                    $appSourceCopJson = @{
                        "mandatoryAffixes" = @($affixes)
                    }
                    if ($obsoleteTagMinAllowedMajorMinor) {
                        $appSourceCopJson += @{
                            "ObsoleteTagMinAllowedMajorMinor" = $obsoleteTagMinAllowedMajorMinor
                        }
                    }
                    if ($supportedCountries) {
                        Write-Host "Using supportedCountries: $([string]::Join(',',$supportedCountries))"
                        $appSourceCopJson += @{
                            "supportedCountries" = @($supportedCountries)
                        }
                    }
                    if ($previousAppVersions.ContainsKey("$($appJson.Publisher)_$($appJson.Name)")) {
                        $previousVersion = $previousAppVersions."$($appJson.Publisher)_$($appJson.Name)"
                        if ($previousVersion -ne $appJson.Version) {
                            $appSourceCopJson += @{
                                "Publisher" = $appJson.Publisher
                                "Name"      = $appJson.Name
                                "Version"   = $previousVersion
                            }
                            Write-Host "Using previous app: $($appJson.Publisher)_$($appJson.Name)_$previousVersion.app"
                        }
                    }
                    $appSourceCopJson | ConvertTo-Json -Depth 99 | Set-Content (Join-Path $tmpFolder "appSourceCop.json") -Encoding UTF8

                    $appSourceRulesetFile = Join-Path $tmpFolder "appsource.default.ruleset.json"
                    Download-File -sourceUrl "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/rulesets/appsource.default.ruleset.json" -destinationFile $appSourceRulesetFile
                    $ruleset.includedRuleSets += @(@{
                            "action" = "Default"
                            "path"   = Get-BcContainerPath -containerName $containerName -path $appSourceRulesetFile
                        })

                    Write-Host "AppSourceCop.json content:"
                    [System.IO.File]::ReadAllLines((Join-Path $tmpFolder "appSourceCop.json")) | Out-Host
                }
                Remove-Item -Path (Join-Path $tmpFolder '*.xml') -Force

                $Parameters = @{
                    "containerName"               = $containerName
                    "credential"                  = $credential
                    "appProjectFolder"            = $tmpFolder
                    "appOutputFolder"             = $tmpFolder
                    "appSymbolsFolder"            = $appPackagesFolder
                    "CopySymbolsFromContainer"    = $true
                    "GenerateReportLayout"        = "No"
                    "EnableAppSourceCop"          = $enableAppSourceCop
                    "EnableUICop"                 = $enableUICop
                    "EnableCodeCop"               = $enableCodeCop
                    "EnablePerTenantExtensionCop" = $enablePerTenantExtensionCop
                    "Reportsuppresseddiagnostics" = $reportsuppresseddiagnostics
                    "outputTo"                    = { Param($line)
                        Write-Host $line
                        if ($line -like "error *" -or $line -like "warning *") {
                            $global:_validationResult += $line
                        }
                        elseif ($line -like "$($tmpFolder)*") {
                            $global:_validationResult += $line.SubString($tmpFolder.Length + 1)
                        }
                    }
                }
                if (!$failOnError) {
                    $Parameters += @{ "ErrorAction" = "SilentlyContinue" }
                }

                if ($ruleset) {
                    $myRulesetFile = Join-Path $tmpFolder "ruleset.json"
                    $ruleset | ConvertTo-Json -Depth 99 | Set-Content $myRulesetFile -Encoding UTF8
                    $Parameters += @{
                        "ruleset" = $myRulesetFile
                    }
                    Write-Host "Ruleset.json content:"
                    [System.IO.File]::ReadAllLines($myRulesetFile) | Out-Host
                }

                try {
                    Invoke-Command -ScriptBlock $CompileAppInBcContainer -ArgumentList ($Parameters) | Out-Null
                }
                catch {
                    Write-Host "ERROR $($_.Exception.Message)"
                    $global:_validationResult += $_.Exception.Message
                }

                if ($ignoreWarnings) {
                    Write-Host "Ignoring warnings"
                    $global:_validationResult = @($global:_validationResult | Where-Object { $_ -notlike "*: warning *" -and $_ -notlike "warning *" })
                }
                if (!$doNotIgnoreInfos) {
                    Write-Host "Ignoring infos"
                    $global:_validationResult = @($global:_validationResult | Where-Object { $_ -notlike "*: info *" -and $_ -notlike "info *" })
                }

                $lines = $global:_validationResult.Length - $length
                if ($lines -gt 0) {
                    $i = 0
                    $global:_validationResult = $global:_validationResult | ForEach-Object {
                        if ($i++ -eq $length) {
                            "$lines $(if ($ignoreWarnings) { "errors" } else { "errors/warnings"}) found in $([System.IO.Path]::GetFileName($appFile)) on $($artifactUrl.Split('?')[0]):"
                        }
                        $_
                    }
                    $global:_validationResult += ""
                }
                Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($appFile, $appPackagesFolder)
                    # Copy inside container to ensure files are ready
                    Write-Host "Copy $appFile to $appPackagesFolder"
                    Copy-Item -Path $appFile -Destination $appPackagesFolder -Force
                } -argumentList (Get-BcContainerPath -containerName $containerName -path $appFile), (Get-BcContainerPath -containerName $containerName -path $appPackagesFolder) | Out-Null
            }
            finally {
                if (Test-Path "$tmpFolder.app") {
                    Remove-Item -Path "$tmpFolder.app" -Force
                }
                if (Test-Path $tmpFolder) {
                    Remove-Item -Path $tmpFolder -Recurse -Force
                }
            }
        }
        if ($appPackFolderCreated) {
            Remove-Item $appPackagesFolder -Recurse -Force
        }
        Remove-Item $appsFolder -Recurse -Force

        $global:_validationResult
        Clear-Variable -Scope global -Name "_validationResult"
    }
    catch {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
        throw
    }
    finally {
        TrackTrace -telemetryScope $telemetryScope
    }
}
Export-ModuleMember -Function Run-AlCops