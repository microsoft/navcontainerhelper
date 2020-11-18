$bcArtifactUrl = Get-BCArtifactUrl -type OnPrem -version "14.0" -country w1
$bcImageName = New-BcImage -artifactUrl $bcArtifactUrl
$bcContainerName = 'bc'
$bcContainerPlatformVersion = '14.0.29530.0'
$bcContainerPath = Join-Path "C:\ProgramData\BcContainerHelper\Extensions" $bcContainerName
$bcMyPath = Join-Path $bcContainerPath "my"
New-BCContainer -accept_eula `
                -accept_outdated `
                -containerName $bcContainerName `
                -artifactUrl $bcArtifactUrl `
                -imageName "myimage" `
                -auth NavUserPassword `
                -Credential $credential `
                -updateHosts `
                -memoryLimit 16g `
                -licenseFile $licenseFile `
                -includeAL `
                -includeTestToolkit `
                -includeTestLibrariesOnly `
                -useBestContainerOS
