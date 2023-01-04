param(
    [switch] $Silent,
    [switch] $ExportTelemetryFunctions,
    [string[]] $bcContainerHelperConfigFile = @(),
    [switch] $useVolumes
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")
. (Join-Path $PSScriptRoot "BC.HelperFunctions.ps1")

if ($isMacOS) {
    throw "BcContainerHelper isn't supported on MacOS"
}
elseif ($isLinux) {
    Write-Warning "BcContainerHelper running on Linux is work-in-progress. Please report any issues on https://github.com/microsoft/navcontainerhelper/issues."
}
elseif ($isPsCore) {
    Write-Warning "BcContainerHelper running on PowerShell7 is work-in-progress. Please report any issues on https://github.com/microsoft/navcontainerhelper/issues."
}

if ($useVolumes -or $isInsideContainer) {
    $bcContainerHelperConfig.UseVolumes = $true
}

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

function VolumeOrPath {
    Param(
        [string] $path
    )

    if (!($path.Contains(':') -or $path.Contains('\') -or $path.Contains('/'))) {
        $volumes = @(docker volume ls --format "{{.Name}}")
        if ($volumes -notcontains $path) {
            docker volume create $path            
        }
        $inspect = (docker volume inspect $path) | ConvertFrom-Json
        return $inspect.MountPoint
    }
    else {
        return $path
    }
}

$bcContainerHelperConfig.bcartifactsCacheFolder = VolumeOrPath $bcContainerHelperConfig.bcartifactsCacheFolder
$bcContainerHelperConfig.hostHelperFolder = VolumeOrPath $bcContainerHelperConfig.HostHelperFolder

$ENV:DOCKER_SCAN_SUGGEST = "$($bcContainerHelperConfig.DOCKER_SCAN_SUGGEST)".ToLowerInvariant()

$sessions = @{}

$extensionsFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions"
if (!(Test-Path -Path $extensionsFolder -PathType Container)) {
    if (!(Test-Path -Path $bcContainerHelperConfig.hostHelperFolder -PathType Container)) {
        New-Item -Path $bcContainerHelperConfig.hostHelperFolder -ItemType Container -Force | Out-Null
    }
    New-Item -Path $extensionsFolder -ItemType Container -Force | Out-Null

    if ($isWindows -and !$isPsCore -and !$isAdministrator) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 3, 'InheritOnly', 'Allow')
        $acl = [System.IO.Directory]::GetAccessControl($bcContainerHelperConfig.hostHelperFolder)
        $acl.AddAccessRule($rule)
        [System.IO.Directory]::SetAccessControl($bcContainerHelperConfig.hostHelperFolder,$acl)
    }
}

if ($isWindows -and !$isPsCore) {
    . (Join-Path $PSScriptRoot "Check-BcContainerHelperPermissions.ps1")
    if (!$silent) {
        Check-BcContainerHelperPermissions -Silent
    }
}

. (Join-Path $PSScriptRoot 'BC.ArtifactsHelper.ps1')
. (Join-Path $PSScriptRoot 'BC.AppSourceHelper.ps1')
. (Join-Path $PSScriptRoot 'BC.ALGoHelper.ps1')
. (Join-Path $PSScriptRoot 'BC.SaasHelper.ps1')
. (Join-Path $PSScriptRoot 'BC.NuGetHelper.ps1')

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

# Container Handling Functions
. (Join-Path $PSScriptRoot "ContainerHandling\Get-NavContainerSession.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Remove-NavContainerSession.ps1")
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
. (Join-Path $PSScriptRoot "ContainerHandling\Flush-ContainerHelperCache.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Get-LatestAlLanguageExtensionUrl.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Get-AlLanguageExtensionFromArtifacts.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\traefik\Add-DomainToTraefikConfig.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Set-BcContainerServerConfiguration.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Restart-BcContainerServiceTier.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Import-TestToolkitToNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Invoke-NavContainerCodeunit.ps1")

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

# Misc functions
. (Join-Path $PSScriptRoot "Misc\Write-NavContainerHelperWelcomeText.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-LocaleFromCountry.ps1")
. (Join-Path $PSScriptRoot "Misc\Get-NavVersionFromVersionInfo.ps1")
. (Join-Path $PSScriptRoot "Misc\Copy-FileFromNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Copy-FileToNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Add-FontsToNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Set-BcContainerFeatureKeys.ps1")
. (Join-Path $PSScriptRoot "Misc\Import-PfxCertificateToNavContainer.ps1")
. (Join-Path $PSScriptRoot "Misc\Import-CertificateToNavContainer.ps1")

# Company Handling functions
. (Join-Path $PSScriptRoot "CompanyHandling\Copy-CompanyInNavContainer.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling\Get-CompanyInNavContainer.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling\New-CompanyInNavContainer.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling\Remove-CompanyInNavContainer.ps1")

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
. (Join-Path $PSScriptRoot "AppHandling\Run-BCPTTestsInBcContainer.ps1")
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

# Api Functions
. (Join-Path $PSScriptRoot "Api\Get-NavContainerApiCompanyId.ps1")
. (Join-Path $PSScriptRoot "Api\Invoke-NavContainerApi.ps1")

# Configuration Package Handling
. (Join-Path $PSScriptRoot "ConfigPackageHandling\Import-ConfigPackageInNavContainer.ps1")
. (Join-Path $PSScriptRoot "ConfigPackageHandling\Remove-ConfigPackageInNavContainer.ps1")
. (Join-Path $PSScriptRoot "ConfigPackageHandling\UploadImportAndApply-ConfigPackageInBcContainer.ps1")

# Container Handling functions
. (Join-Path $PSScriptRoot "ContainerHandling\Enter-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Open-NavContainer.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\New-NavContainerWizard.ps1")

# Traefik Handling functions
. (Join-Path $PSScriptRoot "ContainerHandling\Setup-TraefikContainerForNavContainers.ps1")

# Object Handling functions
. (Join-Path $PSScriptRoot "ObjectHandling\Export-NavContainerObjects.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Create-MyOriginalFolder.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Create-MyDeltaFolder.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Convert-Txt2Al.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Export-ModifiedObjectsAsDeltas.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Convert-ModifiedObjectsToAl.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Import-ObjectsToNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Import-DeltasToNavContainer.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling\Compile-ObjectsInNavContainer.ps1")

# Azure AD specific functions
. (Join-Path $PSScriptRoot "AzureAD\Create-AadAppsForNav.ps1")
. (Join-Path $PSScriptRoot "AzureAD\Create-AadUsersInNavContainer.ps1")

# Azure VM specific functions
. (Join-Path $PSScriptRoot "AzureVM\Replace-NavServerContainer.ps1")
. (Join-Path $PSScriptRoot "AzureVM\New-LetsEncryptCertificate.ps1")
. (Join-Path $PSScriptRoot "AzureVM\Renew-LetsEncryptCertificate.ps1")

# Symbol Handling
. (Join-Path $PSScriptRoot "SymbolHandling\Generate-SymbolsInNavContainer.ps1")

# PackageHandling
. (Join-Path $PSScriptRoot "PackageHandling\Resolve-DependenciesFromAzureFeed.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Publish-BuildOutputToAzureFeed.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Publish-BuildOutputToStorage.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Get-AzureFeedWildcardVersion.ps1")
. (Join-Path $PSScriptRoot "PackageHandling\Install-AzDevops.ps1")

# Business Central Container Script
$bccsFolder = Join-Path $env:APPDATA ".bccs"
if (!(Test-Path -Path $bccsFolder -PathType Container)) {
    New-Item -Path $bccsFolder -ItemType Container -Force -ErrorAction Ignore | Out-Null
}

$bccsScriptFolder = $PSScriptRoot

. (Join-Path $PSScriptRoot "BCCS\BCCS-Update.ps1")
. (Join-Path $PSScriptRoot "BCCS\BCCS-FileManagement.ps1")

. (Join-Path $PSScriptRoot "BCCS\New-BCCSTemplate.ps1")
. (Join-Path $PSScriptRoot "BCCS\Remove-BCCSTemplate.ps1")
. (Join-Path $PSScriptRoot "BCCS\Get-BCCSTemplate.ps1")

. (Join-Path $PSScriptRoot "BCCS\New-BCCSContainerFromTemplate.ps1")
. (Join-Path $PSScriptRoot "BCCS\New-NavContainerFromDeployFile.ps1")

. (Join-Path $PSScriptRoot "BCCS\Get-BCCSRepository.ps1")
. (Join-Path $PSScriptRoot "BCCS\Get-BCCSImage.ps1")

. (Join-Path $PSScriptRoot "BCCS\Show-BCCSAssistant.ps1")