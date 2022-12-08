param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @(),
    [switch] $useVolumes
)

. (Join-Path $PSScriptRoot "InitializeModule.ps1") `
    -Silent:$Silent `
    -bcContainerHelperConfigFile $bcContainerHelperConfigFile `
    -moduleName $MyInvocation.MyCommand.Name `
    -moduleDependencies @( 'BC.HelperFunctions', 'BC.ArtifactsHelper' )

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

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
#
#    if (!$isAdministrator) {
#        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 3, 'InheritOnly', 'Allow')
#        $acl = [System.IO.Directory]::GetAccessControl($bcContainerHelperConfig.hostHelperFolder)
#        $acl.AddAccessRule($rule)
#        [System.IO.Directory]::SetAccessControl($bcContainerHelperConfig.hostHelperFolder,$acl)
#    }
}

#. (Join-Path $PSScriptRoot "Check-BcContainerHelperPermissions.ps1")
#if (!$silent) {
#    Check-BcContainerHelperPermissions -Silent
#}

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
. (Join-Path $PSScriptRoot "ContainerHandling\Set-BcContainerServerConfiguration.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling\Restart-BcContainerServiceTier.ps1")

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
