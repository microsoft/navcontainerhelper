$navImageName = Get-BestBCContainerImageName -ImageName "mcr.microsoft.com/dynamicsnav:2018-cu17-w1"
$navContainerName = 'nav'
$navContainerPlatformVersion = ''
$navContainerPath = Join-Path "C:\ProgramData\BcContainerHelper\Extensions" $navContainerName
$navMyPath = Join-Path $navContainerPath "my"
New-NavContainer -accept_eula `
                 -accept_outdated `
                 -containerName $navContainerName `
                 -imageName $navImageName `
                 -auth NavUserPassword `
                 -Credential $credential `
                 -updateHosts `
                 -memoryLimit 16g `
                 -licenseFile $licenseFile `
                 -includeCSide `
                 -includeTestToolkit `
                 -includeTestLibrariesOnly `
                 -useBestContainerOS
