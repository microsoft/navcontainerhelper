Param(
    [switch] $sandbox
)

$bcContainerName = 'bcs'
$bcContainerPath = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$bcContainerName"
$bcMyPath = Join-Path $bcContainerPath "my"

if ($sandbox) {
    $bcArtifactUrl = Get-BCArtifactUrl -type "Sandbox" -country "us" -select 'Current'
    $artifactPath = Download-Artifacts -artifactUrl $bcArtifactUrl
    $manifest = Get-Content (Join-Path $artifactPath "manifest.json" -Resolve) | ConvertFrom-Json
    $bcImageName = New-BcImage -artifactUrl $bcArtifactUrl -skipIfImageAlreadyExists
    $bcContainerPlatformVersion = $manifest.platform
    New-BCContainer -accept_eula `
                    -accept_outdated `
                    -containerName $bcContainerName `
                    -artifactUrl $bcArtifactUrl `
                    -imageName $bcImageName `
                    -auth UserPassword `
                    -Credential $credential `
                    -updateHosts `
                    -memoryLimit 8g `
                    -licenseFile $buildLicenseFile `
                    -includeTestToolkit `
                    -includeTestLibrariesOnly
}
else {
    $bcArtifactUrl = Get-BCArtifactUrl -type "Sandbox" -country "w1" -select 'Current'
    $artifactPath = Download-Artifacts -artifactUrl $bcArtifactUrl
    $manifest = Get-Content (Join-Path $artifactPath "manifest.json" -Resolve) | ConvertFrom-Json

    $bcImageName = New-BcImage -artifactUrl $bcArtifactUrl -skipIfImageAlreadyExists
    $bcContainerPlatformVersion = $manifest.platform
    New-BCContainer -accept_eula `
                    -accept_outdated `
                    -containerName $bcContainerName `
                    -artifactUrl $bcArtifactUrl `
                    -imageName $bcImageName `
                    -auth UserPassword `
                    -Credential $credential `
                    -updateHosts `
                    -memoryLimit 16g `
                    -licenseFile $buildLicenseFile `
                    -includeAL `
                    -includeTestToolkit `
                    -includeTestLibrariesOnly
}
