Param(
    [switch] $sandbox
)

$credential = [PSCredential]::new("admin", (ConvertTo-SecureString -AsPlainText -String (Get-RandomPassword) -Force))
$bcContainerName = 'bcs'
$bcContainerPath = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$bcContainerName"
$bcMyPath = Join-Path $bcContainerPath "my"

if ($sandbox) {
    $bcArtifactUrl = Get-BCArtifactUrl -type "Sandbox" -version "17.1.18256.30573" -country "us" -select 'Closest'
    $bcImageName = New-BcImage -artifactUrl $bcArtifactUrl -skipIfImageAlreadyExists
    $bcContainerPlatformVersion = "17.0.18204.30560"
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
    $bcArtifactUrl = Get-BCArtifactUrl -type OnPrem -version "17.0" -country w1
    $bcImageName = New-BcImage -artifactUrl $bcArtifactUrl -skipIfImageAlreadyExists
    $bcContainerPlatformVersion = '17.0.16974.0'
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
