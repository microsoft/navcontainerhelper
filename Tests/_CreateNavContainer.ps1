$navArtifactUrl = Get-NavArtifactUrl -nav 2018 -cu 17 -country w1
$navImageName = New-BcImage -artifactUrl $navArtifactUrl -skipIfImageAlreadyExists
$navContainerName = 'nav'
$navContainerPlatformVersion = '11.0.31747.0'
$navContainerPath = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$navContainerName"
$navMyPath = Join-Path $navContainerPath "my"
New-NavContainer -accept_eula `
                 -accept_outdated `
                 -containerName $navContainerName `
                 -artifactUrl $navArtifactUrl `
                 -imagename $navImageName `
                 -auth NavUserPassword `
                 -Credential $credential `
                 -updateHosts `
                 -memoryLimit 8g `
                 -licenseFile $licenseFile `
                 -includeCSide `
                 -includeTestToolkit `
                 -includeTestLibrariesOnly