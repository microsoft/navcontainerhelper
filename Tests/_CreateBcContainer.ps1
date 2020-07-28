$bcImageName = Get-BestBCContainerImageName -ImageName "mcr.microsoft.com/businesscentral/onprem:1904-rtm-w1"
$bcContainerName = 'bc'
$bcContainerPlatformVersion = '14.0.29530.0'
$bcContainerPath = Join-Path "C:\ProgramData\BcContainerHelper\Extensions" $bcContainerName
$bcMyPath = Join-Path $bcContainerPath "my"
New-BCContainer -accept_eula `
                -accept_outdated `
                -containerName $bcContainerName `
                -imageName $bcImageName `
                -auth NavUserPassword `
                -Credential $credential `
                -updateHosts `
                -memoryLimit 16g `
                -licenseFile $licenseFile `
                -includeAL `
                -includeTestToolkit `
                -includeTestLibrariesOnly `
                -useBestContainerOS
