if ($isWindows) {
    $programDataFolder = 'C:\ProgramData\BcContainerHelper'
    $artifactsCacheFolder = "c:\bcartifacts.cache"
}
else {
    $programDataFolder = "/home/$myUsername/.bccontainerhelper"
    $artifactsCacheFolder = "/home/$myUsername/.bcartifacts.cache"
}

function Get-ContainerHelperConfig {
    if (!((Get-Variable -scope Script bcContainerHelperConfig -ErrorAction SilentlyContinue) -and $bcContainerHelperConfig)) {
        Set-Variable -scope Script -Name bcContainerHelperConfig -Value @{
            "bcartifactsCacheFolder" = ""
            "genericImageName" = 'mcr.microsoft.com/businesscentral:{0}'
            "genericImageNameFilesOnly" = 'mcr.microsoft.com/businesscentral:{0}-filesonly'
            "usePsSession" = $isAdministrator -or $isPsCore
            "addTryCatchToScriptBlock" = $true
            "killPsSessionProcess" = $false
            "useVolumes" = $false
            "useVolumeForMyFolder" = $false
            "use7zipIfAvailable" = $true
            "defaultNewContainerParameters" = @{ }
            "hostHelperFolder" = ""
            "containerHelperFolder" = $programDataFolder
            "defaultContainerName" = "bcserver"
            "useCompilerFolder" = $false
            "digestAlgorithm" = "SHA256"
            "timeStampServer" = "http://timestamp.digicert.com"
            "sandboxContainersAreMultitenantByDefault" = $true
            "useSharedEncryptionKeys" = $true
            "DOCKER_SCAN_SUGGEST" = $false
            "psSessionTimeout" = 0
            "baseUrl" = "https://businesscentral.dynamics.com"
            "apiBaseUrl" = "https://api.businesscentral.dynamics.com"
            "mapCountryCode" = [PSCustomObject]@{
                "ae" = "w1"
                "ar" = "w1"
                "bd" = "w1"
                "dz" = "w1"
                "cl" = "w1"
                "pr" = "w1"
                "eg" = "w1"
                "fo" = "dk"
                "gl" = "dk"
                "id" = "w1"
                "ke" = "w1"
                "lb" = "w1"
                "lk" = "w1"
                "lu" = "w1"
                "ma" = "w1"
                "mm" = "w1"
                "mt" = "w1"
                "my" = "w1"
                "ng" = "w1"
                "qa" = "w1"
                "sa" = "w1"
                "sg" = "w1"
                "tn" = "w1"
                "ua" = "w1"
                "za" = "w1"
                "ao" = "w1"
                "bh" = "w1"
                "ba" = "w1"
                "bw" = "w1"
                "cr" = "br"
                "cy" = "w1"
                "do" = "br"
                "ec" = "br"
                "sv" = "br"
                "gt" = "br"
                "hn" = "br"
                "jm" = "w1"
                "mv" = "w1"
                "mu" = "w1"
                "ni" = "br"
                "pa" = "br"
                "py" = "br"
                "tt" = "br"
                "uy" = "br"
                "zw" = "w1"
            }
            "mapNetworkSettings" = [PSCustomObject]@{
            }
            "AddHostDnsServersToNatContainers" = $false
            "TraefikUseDnsNameAsHostName" = $false
            "TreatWarningsAsErrors" = @()
            "PartnerTelemetryConnectionString" = ""
            "MicrosoftTelemetryConnectionString" = "InstrumentationKey=5b44407e-9750-4a07-abe9-30c3b853821b;IngestionEndpoint=https://southcentralus-0.in.applicationinsights.azure.com/"
            "SendExtendedTelemetryToMicrosoft" = $false
            "TraefikImage" = "tobiasfenster/traefik-for-windows:v1.7.34"
            "ObjectIdForInternalUse" = 88123
            "WinRmCredentials" = $null
            "WarningPreference" = "SilentlyContinue"
            "UseNewFormatForGetBcContainerAppInfo" = $false
            "NoOfSecondsToSleepAfterPublishBcContainerApp" = 1
            "RenewClientContextBetweenTests" = $false
            "DebugMode" = $false
            "dotNetCoreRuntimeVersion" = ""
            "dotNetCoreSharedFolder" = ""
        }

        if ($isInsider) {
            $bcContainerHelperConfig.genericImageName = 'mcr.microsoft.com/businesscentral:{0}-dev'
            $bcContainerHelperConfig.genericImageNameFilesOnly = 'mcr.microsoft.com/businesscentral:{0}-filesonly-dev'
        }

        if ($bcContainerHelperConfigFile -notcontains (Join-Path $programDataFolder "BcContainerHelper.config.json")) {
            $bcContainerHelperConfigFile = @((Join-Path $programDataFolder "BcContainerHelper.config.json"))+$bcContainerHelperConfigFile
        }
        $bcContainerHelperConfigFile | ForEach-Object {
            $configFile = $_
            if (Test-Path $configFile) {
                try {
                    $savedConfig = Get-Content $configFile | ConvertFrom-Json
                    if ("$savedConfig") {
                        $keys = $bcContainerHelperConfig.Keys | % { $_ }
                        $keys | ForEach-Object {
                            if ($savedConfig.PSObject.Properties.Name -eq "$_") {
                                if (!$silent) {
                                    Write-Host "Setting $_ = $($savedConfig."$_")"
                                }
                                $bcContainerHelperConfig."$_" = $savedConfig."$_"
                            }
                        }
                    }
                }
                catch {
                    throw "Error reading configuration file $configFile, cannot import module."
                }
            }
        }

        if ($isInsideContainer) {
            $bcContainerHelperConfig.usePsSession = $true
            try {
                $myinspect = docker inspect $(hostname) | ConvertFrom-Json
                $bcContainerHelperConfig.WinRmCredentials = New-Object PSCredential -ArgumentList 'WinRmUser', (ConvertTo-SecureString -string "P@ss$($myinspect.Id.SubString(48))" -AsPlainText -Force)
            }
            catch {}
        }

        if ($bcContainerHelperConfig.dotNetCoreRuntimeVersion -eq "") {
            if ($bcContainerHelperConfig.dotNetCoreSharedFolder -eq "") {
                if ($isWindows) {
                    $bcContainerHelperConfig.dotNetCoreSharedFolder = 'C:\Program Files\dotnet\shared'
                }
                elseif ($IsLinux) {
                    $bcContainerHelperConfig.dotNetCoreSharedFolder = '/usr/share/dotnet/shared'
                    if (-not (Test-Path $bcContainerHelperConfig.dotNetCoreSharedFolder)) {
                        $bcContainerHelperConfig.dotNetCoreSharedFolder = '/home/user/dotnet/shared'
                    }
                }
            }
            if ($bcContainerHelperConfig.dotNetCoreSharedFolder -and (Test-Path $bcContainerHelperConfig.dotNetCoreSharedFolder)) {
                $netCoreAppFolder = Join-Path $bcContainerHelperConfig.dotNetCoreSharedFolder 'Microsoft.NETCore.App'
                if (Test-Path $netCoreAppFolder) {
                    $versions = Get-ChildItem $netCoreAppFolder | ForEach-Object { 
                        try {
                            [System.Version]$_.Name
                        }
                        catch {
                        }
                    }
                    $bcContainerHelperConfig.dotNetCoreRuntimeVersion = $versions | Sort-Object -Descending | Select-Object -First 1 | ForEach-Object { $_.ToString() }
                }
            }
        }

        if ($bcContainerHelperConfig.UseVolumes) {
            if ($bcContainerHelperConfig.bcartifactsCacheFolder -eq "") {
                $bcContainerHelperConfig.bcartifactsCacheFolder = "bcartifacts.cache"
            }
            if ($bcContainerHelperConfig.hostHelperFolder -eq "") {
                $bcContainerHelperConfig.hostHelperFolder = "hostHelperFolder"
            }
            $bcContainerHelperConfig.useVolumeForMyFolder = $false
        }
        else {
            if ($bcContainerHelperConfig.bcartifactsCacheFolder -eq "") {
                $bcContainerHelperConfig.bcartifactsCacheFolder = $artifactsCacheFolder
            }
            if ($bcContainerHelperConfig.hostHelperFolder -eq "") {
                $bcContainerHelperConfig.hostHelperFolder = $programDataFolder
            }
        }

        Export-ModuleMember -Variable bcContainerHelperConfig
    }
    return $bcContainerHelperConfig
}

$configHelperFolder = $programDataFolder
if (!(Test-Path $configHelperFolder)) {
    New-Item -Path $configHelperFolder -ItemType Container -Force | Out-Null
    if ($isWindows -and !$isAdministrator) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 3, 'InheritOnly', 'Allow')
        $acl = Get-Acl -Path $configHelperFolder
        $acl.AddAccessRule($rule)
        Set-Acl -Path $configHelperFolder -AclObject $acl | Out-Null
    }
}

Get-ContainerHelperConfig | Out-Null

$telemetry = @{
    "Assembly" = $null
    "PartnerClient" = $null
    "MicrosoftClient" = $null
    "CorrelationId" = ""
    "TopId" = ""
    "Debug" = $false
}
try {
    if (($bcContainerHelperConfig.MicrosoftTelemetryConnectionString) -and !$Silent) {
        Write-Host -ForegroundColor Green "BC.HelperFunctions emits usage statistics telemetry to Microsoft"
    }
    $dllPath = Join-Path $configHelperFolder 'Microsoft.ApplicationInsights.2.32.0.429.dll'
    if (-not (Test-Path $dllPath)) {
        Copy-Item (Join-Path $PSScriptRoot "Microsoft.ApplicationInsights.dll") -Destination $dllPath
    }
    $telemetry.Assembly = [System.Reflection.Assembly]::LoadFrom($dllPath)
} catch {
    if (!$Silent) {
        Write-Host -ForegroundColor Yellow "Unable to load ApplicationInsights.dll"
    }
}

. (Join-Path $PSScriptRoot "TelemetryHelper.ps1")

# Telemetry functions
Export-ModuleMember -Function RegisterTelemetryScope
Export-ModuleMember -Function InitTelemetryScope
Export-ModuleMember -Function AddTelemetryProperty
Export-ModuleMember -Function TrackTrace
Export-ModuleMember -Function TrackException

# Common functions
. (Join-Path $PSScriptRoot "Common\Download-File.ps1")
. (Join-Path $PSScriptRoot "Common\New-DesktopShortcut.ps1")
. (Join-Path $PSScriptRoot "Common\Remove-DesktopShortcut.ps1")
. (Join-Path $PSScriptRoot "Common\ConvertTo-HashTable.ps1")
. (Join-Path $PSScriptRoot "Common\Get-PlainText.ps1")
. (Join-Path $PSScriptRoot "Common\Invoke-gh.ps1")
. (Join-Path $PSScriptRoot "Common\Invoke-git.ps1")
. (Join-Path $PSScriptRoot "Common\ConvertTo-OrderedDictionary.ps1")

# BC Authentication helper functions
. (Join-Path $PSScriptRoot "Auth\New-BcAuthContext.ps1")
. (Join-Path $PSScriptRoot "Auth\Renew-BcAuthContext.ps1")
