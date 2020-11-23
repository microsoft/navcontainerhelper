$bcArtifactUrl = Get-BCArtifactUrl -type OnPrem -version "17.0" -country w1
$bcImageName = New-BcImage -artifactUrl $bcArtifactUrl -skipIfImageAlreadyExists
$bcContainerName = 'bco'
$bcContainerPlatformVersion = '17.0.16993.0'
$bcContainerPath = Join-Path "C:\ProgramData\BcContainerHelper\Extensions" $bcContainerName
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
                -licenseFile $licenseFile `
                -includeAL `
                -includeTestToolkit `
                -includeTestLibrariesOnly

$bcsArtifactUrl = Get-BCArtifactUrl -type Sandbox -country us
$bcsImageName = New-BcImage -artifactUrl $bcsArtifactUrl -skipIfImageAlreadyExists
$bcsContainerName = 'bcs'
$bcsContainerPath = Join-Path "C:\ProgramData\BcContainerHelper\Extensions" $bcsContainerName
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
                -licenseFile $licenseFile `
                -includeAL `
                -includeTestToolkit `
                -includeTestLibrariesOnly

$bcsContainerPlatformVersion = Get-BcContainerPlatformVersion -containerOrImageName $bcsContainerName
if (!($bcsContainerPlatformVersion)) {
    throw "Couldn't get platform version from Sandbox container"
}
