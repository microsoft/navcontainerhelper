$navArtifactUrl = Get-NavArtifactUrl -nav 2018 -cu 17 -country w1
$navImageName = New-BcImage -artifactUrl $navArtifactUrl
$navContainerName = 'nav'
$navContainerPlatformVersion = ''
$navContainerPath = Join-Path "C:\ProgramData\BcContainerHelper\Extensions" $navContainerName
$navMyPath = Join-Path $navContainerPath "my"
New-NavContainer -accept_eula `
                 -accept_outdated `
                 -containerName $navContainerName `
                 -artifactUrl $navArtifactUrl `
                 -imageName "myimage" `
                 -auth NavUserPassword `
                 -Credential $credential `
                 -updateHosts `
                 -memoryLimit 16g `
                 -licenseFile $licenseFile `
                 -includeCSide `
                 -includeTestToolkit `
                 -includeTestLibrariesOnly `
                 -useBestContainerOS
