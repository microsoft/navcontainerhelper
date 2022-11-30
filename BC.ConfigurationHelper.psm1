param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @()
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name

function Get-ContainerHelperConfig {
    if (!((Get-Variable -scope Script bcContainerHelperConfig -ErrorAction SilentlyContinue) -and $bcContainerHelperConfig)) {
        Set-Variable -scope Script -Name bcContainerHelperConfig -Value @{
            "bcartifactsCacheFolder" = ""
            "genericImageName" = 'mcr.microsoft.com/businesscentral:{0}'
            "genericImageNameFilesOnly" = 'mcr.microsoft.com/businesscentral:{0}-filesonly'
            "usePsSession" = $isAdministrator # -and ("$ENV:GITHUB_ACTIONS" -ne "true") -and ("$ENV:TF_BUILD" -ne "true")
            "addTryCatchToScriptBlock" = $true
            "killPsSessionProcess" = $false
            "useVolumes" = $false
            "useVolumeForMyFolder" = $false
            "use7zipIfAvailable" = $true
            "defaultNewContainerParameters" = @{ }
            "hostHelperFolder" = ""
            "containerHelperFolder" = "C:\ProgramData\BcContainerHelper"
            "defaultContainerName" = "bcserver"
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
        }

        if ($isInsider) {
            $bcContainerHelperConfig.genericImageName = 'mcr.microsoft.com/businesscentral:{0}-dev'
            $bcContainerHelperConfig.genericImageNameFilesOnly = 'mcr.microsoft.com/businesscentral:{0}-filesonly-dev'
        }

        if ($bcContainerHelperConfigFile -notcontains "C:\ProgramData\BcContainerHelper\BcContainerHelper.config.json") {
            $bcContainerHelperConfigFile = @("C:\ProgramData\BcContainerHelper\BcContainerHelper.config.json")+$bcContainerHelperConfigFile
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
                $bcContainerHelperConfig.bcartifactsCacheFolder = "c:\bcartifacts.cache"
            }
            if ($bcContainerHelperConfig.hostHelperFolder -eq "") {
                $bcContainerHelperConfig.hostHelperFolder = "C:\ProgramData\BcContainerHelper"
            }
        }

        Export-ModuleMember -Variable bcContainerHelperConfig
    }
    return $bcContainerHelperConfig
}

Get-ContainerHelperConfig | Out-Null

# There can be no functions exposed from the configuration module
