#Requires -PSEdition Desktop 

param(
    [switch] $Silent
)

Set-StrictMode -Version 2.0

$verbosePreference = "SilentlyContinue"
$warningPreference = 'Continue'
$errorActionPreference = 'Stop'

if ([intptr]::Size -eq 4) {
    throw "ContainerHelper cannot run in Windows PowerShell (x86), need 64bit mode"
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try {
    $myUsername = $currentPrincipal.Identity.Name
} catch {
    $myUsername = (whoami)
}

function Get-ContainerHelperConfig {
    if (!((Get-Variable -scope Script bcContainerHelperConfig -ErrorAction SilentlyContinue) -and $bcContainerHelperConfig)) {
        Set-Variable -scope Script -Name bcContainerHelperConfig -Value @{
            "bcartifactsCacheFolder" = "c:\bcartifacts.cache"
            "genericImageName" = 'mcr.microsoft.com/businesscentral:{0}'
            "genericImageNameFilesOnly" = 'mcr.microsoft.com/businesscentral:{0}-filesonly'
            "usePsSession" = $isAdministrator
            "use7zipIfAvailable" = $true
            "defaultNewContainerParameters" = @{ }
            "hostHelperFolder" = "C:\ProgramData\BcContainerHelper"
            "containerHelperFolder" = "C:\ProgramData\BcContainerHelper"
            "defaultContainerName" = "bcserver"
            "digestAlgorithm" = "SHA256"
            "timeStampServer" = "http://timestamp.digicert.com"
            "sandboxContainersAreMultitenantByDefault" = $true
            "useSharedEncryptionKeys" = $true
            "DOCKER_SCAN_SUGGEST" = $false
            "psSessionTimeout" = 0
            "mapCountryCode" = [PSCustomObject]@{
                "ae" = "w1"
                "br" = "w1"
                "bd" = "w1"
                "co" = "w1"
                "dz" = "w1"
                "ee" = "w1"
                "eg" = "w1"
                "fo" = "dk"
                "gl" = "dk"
                "gr" = "w1"
                "hk" = "w1"
                "hr" = "w1"
                "hu" = "w1"
                "id" = "w1"
                "ie" = "w1"
                "jp" = "w1"
                "ke" = "w1"
                "kr" = "w1"
                "lb" = "w1"
                "lk" = "w1"
                "lt" = "w1"
                "lu" = "w1"
                "lv" = "w1"
                "ma" = "w1"
                "mm" = "w1"
                "mt" = "w1"
                "my" = "w1"
                "ng" = "w1"
                "pe" = "w1"
                "ph" = "w1"
                "pl" = "w1"
                "qa" = "w1"
                "rs" = "w1"
                "ro" = "w1"
                "sa" = "w1"
                "sg" = "w1"
                "si" = "w1"
                "th" = "w1"
                "tn" = "w1"
                "tw" = "w1"
                "vn" = "w1"
                "za" = "w1"
            }
            "TraefikUseDnsNameAsHostName" = $false
            "TreatWarningsAsErrors" = @('AL1026')
            "TelemetryConnectionString" = ""
        }
        $bcContainerHelperConfigFile = "C:\ProgramData\BcContainerHelper\BcContainerHelper.config.json"
        if (Test-Path $bcContainerHelperConfigFile) {
            try {
                $savedConfig = Get-Content $bcContainerHelperConfigFile | ConvertFrom-Json
                if ("$savedConfig") {
                    $keys = $bcContainerHelperConfig.Keys | % { $_ }
                    $keys | % {
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
                throw "Error reading configuration file $bcContainerHelperConfigFile, cannot import module."
            }
        }
        Export-ModuleMember -Variable bcContainerHelperConfig
    }
    return $bcContainerHelperConfig
}

Get-ContainerHelperConfig | Out-Null

$hypervState = ""
function Get-HypervState {
    if ($isAdministrator -and $hypervState -eq "") {
        $feature = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online
        if ($feature) {
            $script:hypervState = $feature.State
        }
        else {
            $script:hypervState = "Disabled"
        }
    }
    return $script:hypervState
}

$Source = @"
	using System.Net;
 
	public class TimeoutWebClient : WebClient
	{
        int theTimeout;

        public TimeoutWebClient(int timeout)
        {
            theTimeout = timeout;
        }

		protected override WebRequest GetWebRequest(System.Uri address)
		{
			WebRequest request = base.GetWebRequest(address);
			if (request != null)
			{
				request.Timeout = theTimeout;
			}
			return request;
		}
 	}
"@;
 
try {
    Add-Type -TypeDefinition $Source -Language CSharp -WarningAction SilentlyContinue | Out-Null
}
catch {}

$hostHelperFolder = $bcContainerHelperConfig.HostHelperFolder
$extensionsFolder = Join-Path $hostHelperFolder "Extensions"
$containerHelperFolder = $bcContainerHelperConfig.ContainerHelperFolder

$BcContainerHelperVersion = Get-Content (Join-Path $PSScriptRoot "Version.txt")
if (!$silent) {
    Write-Host "BcContainerHelper version $BcContainerHelperVersion"
}

$ENV:DOCKER_SCAN_SUGGEST = "$($bcContainerHelperConfig.DOCKER_SCAN_SUGGEST)".ToLowerInvariant()

try {
    Add-Type -path (Join-Path $PSScriptRoot "Microsoft.ApplicationInsights.dll") -ErrorAction SilentlyContinue
} catch {}
$telemetryClient = New-Object Microsoft.ApplicationInsights.TelemetryClient
$telemetryClient.TelemetryConfiguration.DisableTelemetry = $true

$sessions = @{}

if (!(Test-Path -Path $extensionsFolder -PathType Container)) {
    if (!(Test-Path -Path $hostHelperFolder -PathType Container)) {
        New-Item -Path $hostHelperFolder -ItemType Container -Force | Out-Null
    }
    New-Item -Path $extensionsFolder -ItemType Container -Force | Out-Null

    if (!$isAdministrator) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 3, 'InheritOnly', 'Allow')
        $acl = [System.IO.Directory]::GetAccessControl($hostHelperFolder)
        $acl.AddAccessRule($rule)
        [System.IO.Directory]::SetAccessControl($hostHelperFolder,$acl)
    }
}

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")
. (Join-Path $PSScriptRoot "TelemetryHelper.ps1")
. (Join-Path $PSScriptRoot "Check-BcContainerHelperPermissions.ps1")

Check-BcContainerHelperPermissions -Silent

# Container Info functions
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerNavVersion.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerPlatformVersion.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerImageName.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerArtifactUrl.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerGenericTag.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerOsVersion.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerEula.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerLegal.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerCountry.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerIpAddress.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerSharedFolders.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerPath.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerName.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerDebugInfo")
. (Join-Path $PSScriptRoot "ContainerInfo\Test-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerId.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainers.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerEventLog.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerServerConfiguration")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerImageLabels")
. (Join-Path $PSScriptRoot "ContainerInfo\Get-NavContainerImageTags")

# Api Functions
. (Join-Path $PSScriptRoot "Api\Get-NavContainerApiCompanyId.ps1")
. (Join-Path $PSScriptRoot "Api\Invoke-NavContainerApi.ps1")

# Container Handling Functions
. (Join-Path $PSScriptRoot "ContainerHandling\Get-NavContainerSession.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Remove-NavContainerSession.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Enter-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Open-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\New-NavContainerWizard.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\New-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\New-NavImage.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Restart-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Stop-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Start-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Import-NavContainerLicense.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Set-BcContainerKeyVaultAadAppAndCertificate.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Remove-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Wait-NavContainerReady.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Extract-FilesFromNavContainerImage.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Extract-FilesFromStoppedNavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Get-BestNavContainerImageName.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Get-BestGenericImageName.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Invoke-ScriptInNavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Setup-TraefikContainerForNavContainers.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Flush-ContainerHelperCache.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Get-LatestAlLanguageExtensionUrl.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Get-AlLanguageExtensionFromArtifacts.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\traefik\Add-DomainToTraefikConfig.ps1")

# Object Handling functions
. (Join-Path $PSScriptRoot "ObjectHandling\Export-NavContainerObjects.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Create-MyOriginalFolder.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Create-MyDeltaFolder.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Convert-Txt2Al.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Export-ModifiedObjectsAsDeltas.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Convert-ModifiedObjectsToAl.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Import-ObjectsToNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Import-DeltasToNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Import-TestToolkitToNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Compile-ObjectsInNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Invoke-NavContainerCodeunit.ps1")

# App Handling functions
. (Join-Path $PSScriptRoot "AppHandling\Publish-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Repair-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Sync-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Install-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Start-NavContainerAppDataUpgrade.ps1")
. (Join-Path $PSScriptRoot "AppHandling\UnInstall-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\UnPublish-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Get-NavContainerAppInfo.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Compile-AppInNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Convert-ALCOutputToAzureDevOps.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Install-NAVSipCryptoProviderFromNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Sign-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Get-NavContainerAppRuntimePackage.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Convert-BcAppsToRuntimePackages.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Get-NavContainerApp.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Extract-AppFileToFolder.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Replace-DependenciesInAppFile.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Run-TestsInNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Run-ConnectionTestToNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Get-TestsFromNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Create-AlProjectFolderFromNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Publish-NewApplicationToNavContainer.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Copy-AlSourceFiles.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Clean-BcContainerDatabase.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Add-GitToAlProjectFolder.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Sort-AppFoldersByDependencies.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Sort-AppFilesByDependencies.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Run-AlPipeline.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Run-AlValidation.ps1")
. (Join-Path $PSScriptRoot "AppHandling\Run-AlCops.ps1")

# Tenant Handling functions
. (Join-Path $PSScriptRoot "TenantHandling\New-NavContainerTenant.ps1")
. (Join-Path $PSScriptRoot "TenantHandling\Remove-NavContainerTenant.ps1")
. (Join-Path $PSScriptRoot "TenantHandling\Get-NavContainerTenants.ps1")

# Bacpac Handling functions
. (Join-Path $PSScriptRoot "Bacpac\Export-NavContainerDatabasesAsBacpac.ps1")
. (Join-Path $PSScriptRoot "Bacpac\Backup-NavContainerDatabases.ps1")
. (Join-Path $PSScriptRoot "Bacpac\Restore-DatabasesInNavContainer.ps1")
. (Join-Path $PSScriptRoot "Bacpac\Restore-BcDatabaseFromArtifacts.ps1")
. (Join-Path $PSScriptRoot "Bacpac\Remove-BcDatabase.ps1")

# User Handling functions
. (Join-Path $PSScriptRoot "UserHandling\Get-NavContainerNavUser.ps1")
. (Join-Path $PSScriptRoot "UserHandling\New-NavContainerNavUser.ps1")
. (Join-Path $PSScriptRoot "UserHandling\New-NavContainerWindowsUser.ps1")
. (Join-Path $PSScriptRoot "UserHandling\Setup-NavContainerTestUsers.ps1")

# Azure AD specific functions
. (Join-Path $PSScriptRoot "AzureAD\Create-AadAppsForNav.ps1")
. (Join-Path $PSScriptRoot "AzureAD\Create-AadUsersInNavContainer.ps1")

# BC SaaS specific functions
. (Join-Path $PSScriptRoot "BcSaaS\New-BcAuthContext.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Renew-BcAuthContext.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Get-BcEnvironments.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Get-BcPublishedApps.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Get-BcInstalledExtensions.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Install-BcAppFromAppSource")
. (Join-Path $PSScriptRoot "BcSaaS\Publish-PerTenantExtensionApps.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\New-BcEnvironment.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Remove-BcEnvironment.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Set-BcEnvironmentApplicationInsightsKey.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\Get-BcDatabaseExportHistory.ps1")
. (Join-Path $PSScriptRoot "BcSaaS\New-BcDatabaseExport.ps1")

# Azure VM specific functions
. (Join-Path $PSScriptRoot "AzureVM\Replace-NavServerContainer.ps1")
. (Join-Path $PSScriptRoot "AzureVM\New-LetsEncryptCertificate.ps1")
. (Join-Path $PSScriptRoot "AzureVM\Renew-LetsEncryptCertificate.ps1")

# Misc functions
. (Join-Path $PSScriptRoot "Misc\New-DesktopShortcut.ps1")
. (Join-Path $PSScriptRoot "Misc\Remove-DesktopShortcut.ps1")
. (Join-Path $PSScriptRoot "Misc\Write-NavContainerHelperWelcomeText.ps1")
. (Join-Path $PSScriptRoot "Misc\Download-File.ps1")
. (Join-Path $PSScriptRoot "Misc\Download-Artifacts.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-BcArtifactUrl.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-NavArtifactUrl.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-LocaleFromCountry.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-NavVersionFromVersionInfo.ps1")
. (Join-Path $PSScriptRoot "Misc\Copy-FileFromNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Copy-FileToNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Add-FontsToNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Set-BcContainerFeatureKeys.ps1")
. (Join-Path $PSScriptRoot "Misc\Import-PfxCertificateToNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-PlainText.ps1")

# Company Handling functions
. (Join-Path $PSScriptRoot "CompanyHandling\Copy-CompanyInNavContainer.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling\Get-CompanyInNavContainer.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling\New-CompanyInNavContainer.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling\Remove-CompanyInNavContainer.ps1")

# Configuration Package Handling
. (Join-Path $PSScriptRoot "ConfigPackageHandling\Import-ConfigPackageInNavContainer.ps1")
. (Join-Path $PSScriptRoot "ConfigPackageHandling\Remove-ConfigPackageInNavContainer.ps1")
. (Join-Path $PSScriptRoot "ConfigPackageHandling\UploadImportAndApply-ConfigPackageInBcContainer.ps1")

# Symbol Handling
. (Join-Path $PSScriptRoot "SymbolHandling\Generate-SymbolsInNavContainer.ps1")

# PackageHandling
. (Join-Path $PSScriptRoot "PackageHandling\Resolve-DependenciesFromAzureFeed.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Publish-BuildOutputToAzureFeed.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Publish-BuildOutputToStorage.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Get-AzureFeedWildcardVersion.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Install-AzDevops.ps1")