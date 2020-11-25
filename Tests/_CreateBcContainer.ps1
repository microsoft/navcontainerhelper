$bcArtifactUrl = Get-BCArtifactUrl -type OnPrem -version "17.0" -country w1
$bcImageName = New-BcImage -artifactUrl $bcArtifactUrl -skipIfImageAlreadyExists
$bcContainerName = 'bco'
$bcContainerPlatformVersion = '17.0.16974.0'
$bcContainerPath = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$bcContainerName"
$bcMyPath = Join-Path $bcContainerPath "my"
New-BCContainer -accept_eula `
                -accept_outdated `
                -containerName $bcContainerName `
                -artifactUrl $bcArtifactUrl `
                -imageName $bcImageName `
                -auth NavUserPassword `
                -Credential $credential `
                -updateHosts `
                -memoryLimit 16g `
                -licenseFile $buildLicenseFile `
                -includeAL `
                -includeTestToolkit `
                -includeTestLibrariesOnly

$bcsArtifactUrl = Get-BCArtifactUrl -type "Sandbox" -version "17.1.18256.19244" -country "us"
$bcsImageName = New-BcImage -artifactUrl $bcsArtifactUrl -skipIfImageAlreadyExists
$bcsContainerName = 'bcs'
$bcsContainerPlatformVersion = "17.0.18204.19144"
$bcsContainerPath = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$bcsContainerName"
$bcsMyPath = Join-Path $bcsContainerPath "my"
New-BCContainer -accept_eula `
                -accept_outdated `
                -containerName $bcsContainerName `
                -artifactUrl $bcsArtifactUrl `
                -imageName $bcsImageName `
                -auth NavUserPassword `
                -Credential $credential `
                -updateHosts `
                -memoryLimit 8g `
                -licenseFile $buildLicenseFile `
                -includeTestToolkit `
                -includeTestLibrariesOnly

