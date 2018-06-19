# This script performs a simple happy-path test of most navcontainerhelper functions

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\..\NavContainerHelper.ps1")
. (Join-Path $PSScriptRoot "..\settings.ps1")

$containerName = "test"

$fobPath = (Join-Path $PSScriptRoot "test.fob")
$txtPath = (Join-Path $PSScriptRoot "test.txt")
$deltaPath = (Join-Path $PSScriptRoot "delta")
$v1AppPath = (Join-Path $PSScriptRoot "test.navx")
$v1AppName = "Test"
$v2AppPath = (Join-Path $PSScriptRoot "Freddy Kristiansen_mytestapp_1.0.0.0.app")
$v2AppName = "mytestapp"

# New-CSideDevContainer
New-CSideDevContainer -accept_eula `
                      -containerName $containerName `
                      -imageName $imageName `
                      -licenseFile $licenseFile `
                      -credential $credential `
                      -UpdateHosts `
                      -Auth Windows `
                      -additionalParameters @("--volume ""${deltaPath}:c:\deltas""")

# Test-NavContainer
if (Test-NavContainer -containerName $containerName) {
    Write-Host "$containerName is running!"
}

# Get-NavContainerNavVersion
$navVersion = Get-NavContainerNavVersion -containerOrImageName $imageName
Write-Host "Nav Version of $imageName is $navVersion"
$navVersion = Get-NavContainerNavVersion -containerOrImageName $containerName
Write-Host "Nav Version of $containerName is $navVersion"

# Get-NavContainerImageName
$imageName = Get-NavContainerImageName -containerName $containerName
Write-Host "ImageName of $containerName is $imageName"

# Get-NavContainerGenericTag
$tag = Get-NavContainerGenericTag -containerOrImageName $imageName
Write-Host "Generic tag of $imageName is $tag"
$tag = Get-NavContainerGenericTag -containerOrImageName $containerName
Write-Host "Generic tag of $containerName is $tag"

# Get-NavContainerOsVersion
$osversion = Get-NavContainerOsVersion -containerOrImageName $imageName
Write-Host "OS Version of $imageName is $osversion"
$osversion = Get-NavContainerOsVersion -containerOrImageName $containerName
Write-Host "OS Version of $containerName is $osversion"

# Get-NavContainerLegal
$legal = Get-NavContainerLegal -containerOrImageName $imageName
Write-Host "Legal link of $imageName is $legal"
$legal = Get-NavContainerLegal -containerOrImageName $containerName
Write-Host "Legal link of $containerName is $legal"

# Get-NavContainerCountry
$country = Get-NavContainerCountry -containerOrImageName $imageName
Write-Host "Country of $imageName is $country"
$country = Get-NavContainerCountry -containerOrImageName $containerName
Write-Host "Country of $containerName is $country"

# Get-NavContainerIpAddress
$ipAddress = Get-NavContainerIpAddress -containerName $containerName
Write-Host "IP Address of $containerName is $ipAddress"

# Get-NavContainerSharedFolders
$sharedFolders = Get-NavContainerSharedFolders -containerName $containerName
Write-Host "Shared Folders with $containerName are:"
$sharedFolders.GetEnumerator() | ForEach-Object { Write-Host ($_.Name + " -> " + $_.Value) }

# Get-NavContainerPath
$path = "c:\programdata\navcontainerhelper\extensions\$containerName\my\AdditionalSetup.ps1"
$containerPath = Get-NavContainerPath -containerName $containerName -path $path
Write-Host "Container Path of $path in $containerName is $containerPath"

# Get-NavContainerId
$containerId = Get-NavcontainerId -containerName $containerName
Write-Host "Id of $containerName is $containerId"

# Get-NavContainerName
$containerName = Get-NavcontainerName -containerId $containerId
Write-Host "Name of $containerId is $containerName"

# Import-ObjectsToNavContainer (.fob)
Import-ObjectsToNavContainer -containerName $containerName `
                             -objectsFile $fobPath

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName

# Import-ObjectsToNavContainer (.txt)
Import-ObjectsToNavContainer -containerName $containerName `
                             -objectsFile $txtPath

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName

# Import-ObjectsToNavContainer (.txt)
Import-DeltasToNavContainer -containerName $containerName `
                            -deltaFolder $deltaPath

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName

# Convert-ModifiedObjectsToAl
Convert-ModifiedObjectsToAl -containerName $containerName `
                            -startId 50100

# Install NavSip
Install-NAVSipCryptoProviderFromNavContainer -containerName $containerName

# App Handling functions v1 extensions
if (Test-Path $v1AppPath) {
    Publish-NavContainerApp -containerName $containerName -appFile $v1AppPath
    Get-NavContainerAppInfo -containerName $containerName
    Install-NavContainerApp -containerName $containerName -appName $v1AppName
    Uninstall-NavContainerApp -containerName $containerName -appName $v1AppName
    Unpublish-NavContainerApp -containerName $containerName -appName $v1AppName
    Get-NavContainerAppInfo -containerName $containerName
}

if (Test-Path "$v2AppPath") {
    # App Handling functions v2 extensions
    Publish-NavContainerApp -containerName $containerName -appFile "$v2AppPath" -skipVerification
    Get-NavContainerAppInfo -containerName $containerName
    Sync-NavContainerApp -containerName $containerName -appName $v2AppName
    Install-NavContainerApp -containerName $containerName -appName $v2AppName
    Uninstall-NavContainerApp -containerName $containerName -appName $v2AppName
    Unpublish-NavContainerApp -containerName $containerName -appName $v2AppName
    Get-NavContainerAppInfo -containerName $containerName
}

# Remove-NavContainer
Remove-NavContainer -containerName $containerName

# New-CSideDevContainer
New-CSideDevContainer -accept_eula `
                      -containerName $containerName `
                      -imageName $imageName2 `
                      -licenseFile $licenseFile `
                      -credential $credential `
                      -UpdateHosts `
                      -Auth NavUserPassword

# Test-NavContainer
if (Test-NavContainer -containerName $containerName) {
    Write-Host "$containerName is running!"
}

# Get-NavContainerNavVersion
$navVersion = Get-NavContainerNavVersion -containerOrImageName $imageName2
Write-Host "Nav Version of $imageName2 is $navVersion"
$navVersion = Get-NavContainerNavVersion -containerOrImageName $containerName
Write-Host "Nav Version of $containerName is $navVersion"

# Get-NavContainerImageName
$imageName2 = Get-NavContainerImageName -containerName $containerName
Write-Host "ImageName of $containerName is $imageName2"

# Get-NavContainerGenericTag
$tag = Get-NavContainerGenericTag -containerOrImageName $imageName2
Write-Host "Generic tag of $imageName2 is $tag"
$tag = Get-NavContainerGenericTag -containerOrImageName $containerName
Write-Host "Generic tag of $containerName is $tag"

# Get-NavContainerOsVersion
$osversion = Get-NavContainerOsVersion -containerOrImageName $imageName2
Write-Host "OS Version of $imageName2 is $osversion"
$osversion = Get-NavContainerOsVersion -containerOrImageName $containerName
Write-Host "OS Version of $containerName is $osversion"

# Get-NavContainerLegal
$legal = Get-NavContainerLegal -containerOrImageName $imageName2
Write-Host "Legal link of $imageName2 is $legal"
$legal = Get-NavContainerLegal -containerOrImageName $containerName
Write-Host "Legal link of $containerName is $legal"

# Get-NavContainerCountry
$country = Get-NavContainerCountry -containerOrImageName $imageName2
Write-Host "Country of $imageName2 is $country"
$country = Get-NavContainerCountry -containerOrImageName $containerName
Write-Host "Country of $containerName is $country"

# Get-NavContainerIpAddress
$ipAddress = Get-NavContainerIpAddress -containerName $containerName
Write-Host "IP Address of $containerName is $ipAddress"

# Get-NavContainerSharedFolders
$sharedFolders = Get-NavContainerSharedFolders -containerName $containerName
Write-Host "Shared Folders with $containerName are:"
$sharedFolders.GetEnumerator() | ForEach-Object { Write-Host ($_.Name + " -> " + $_.Value) }

# Get-NavContainerPath
$path = "c:\programdata\navcontainerhelper\extensions\$containerName\my\AdditionalSetup.ps1"
$containerPath = Get-NavContainerPath -containerName $containerName -path $path
Write-Host "Container Path of $path in $containerName is $containerPath"

# Get-NavContainerId
$containerId = Get-NavcontainerId -containerName $containerName
Write-Host "Id of $containerName is $containerId"

# Get-NavContainerName
$containerName = Get-NavcontainerName -containerId $containerId
Write-Host "Name of $containerId is $containerName"

# Import-ObjectsToNavContainer (.fob)
Import-ObjectsToNavContainer -containerName $containerName `
                             -objectsFile $fobPath `
                             -sqlCredential $sqlCredential

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName `
                              -sqlCredential $sqlCredential

# Import-ObjectsToNavContainer (.txt)
Import-ObjectsToNavContainer -containerName $containerName `
                             -objectsFile $txtPath `
                             -sqlCredential $sqlCredential

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName `
                              -sqlCredential $sqlCredential

# Convert-ModifiedObjectsToAl
Convert-ModifiedObjectsToAl -containerName $containerName `
                            -sqlCredential $sqlCredential `
                            -startId 50100

# Remove-NavContainer
Remove-NavContainer -containerName $containerName
