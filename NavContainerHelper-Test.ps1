$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "NavContainerHelper.ps1")

# This script performs a simple happy-path test of most navcontainerhelper functions

$imageName = "navdocker.azurecr.io/dynamics-nav:11.0.18920.0"
$containerName = "test"

$username = $env:USERNAME
$password = Read-Host -AsSecureString -Prompt "Please enter the admin password for Nav Container"

# TEMP solution: The following files must exist
$licenseFile = "c:\temp\license.flf"

$fobPath = "C:\temp\Test.fob"
$txtPath = "C:\temp\Test.txt"

$v1AppPath = "C:\temp\Search2.navx"
$v1AppName = "Search"

$v2AppPath = "C:\temp\uns\Search2.app"
$v2AppName = "Search"

docker pull $imageName

# New-CSideDevContainer
New-CSideDevContainer -containerName $containerName `
                      -devImageName $imageName `
                      -licenseFile $licenseFile `
                      -vmAdminUsername $username `
                      -adminPassword $password `
                      -UpdateHosts `
                      -Auth Windows

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
$sharedFolders.GetEnumerator() | % { Write-Host ($_.Name + " -> " + $_.Value) }

# Get-NavContainerPath
$path = "c:\demo\extensions\$containerName\my\AdditionalSetup.ps1"
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

if (Test-Path $v2AppPath) {
    # App Handling functions v2 extensions
    Publish-NavContainerApp -containerName $containerName -appFile $v2AppPath
    Get-NavContainerAppInfo -containerName $containerName
    Sync-NavContainerApp -containerName $containerName -appName $v2AppName
    Install-NavContainerApp -containerName $containerName -appName $v2AppName
    Uninstall-NavContainerApp -containerName $containerName -appName $v2AppName
    Unpublish-NavContainerApp -containerName $containerName -appName $v2AppName
    Get-NavContainerAppInfo -containerName $containerName
}

# Remove-NavContainer
Remove-NavContainer -containerName $containerName -UpdateHosts

# New-CSideDevContainer
New-CSideDevContainer -containerName $containerName `
                      -devImageName $imageName `
                      -licenseFile $licenseFile `
                      -vmAdminUsername $username `
                      -adminPassword $password `
                      -UpdateHosts `
                      -Auth NavUserPassword

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
$sharedFolders.GetEnumerator() | % { Write-Host ($_.Name + " -> " + $_.Value) }

# Get-NavContainerPath
$path = "c:\demo\extensions\$containerName\my\AdditionalSetup.ps1"
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
                             -adminPassword $password

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName `
                              -adminPassword $password

# Import-ObjectsToNavContainer (.txt)
Import-ObjectsToNavContainer -containerName $containerName `
                             -objectsFile $txtPath `
                             -adminPassword $password

# Compile-ObjectsToNavContainer
Compile-ObjectsInNavContainer -containerName $containerName `
                              -adminPassword $password

# Convert-ModifiedObjectsToAl
Convert-ModifiedObjectsToAl -containerName $containerName `
                            -adminPassword $password `
                            -startId 50100

# Remove-NavContainer
Remove-NavContainer -containerName $containerName -UpdateHosts


#help Get-NavContainerNavVersion    -full
#help Get-NavContainerImageName     -full
#help Get-NavContainerGenericTag    -full
#help Get-NavContainerOsVersion     -full
#help Get-NavContainerLegal         -full
#help Get-NavContainerCountry       -full
#help Get-NavContainerIpAddress     -full
#help Get-NavContainerSharedFolders -full
#help Get-NavContainerPath          -full
#help Get-NavContainerName          -full
#help Get-NavContainerId            -full
#help Test-NavContainer             -full
#help New-CSideDevContainer         -full
#help New-NavContainer              -full
#help Remove-NavContainer           -full
#help Get-NavContainerSession       -full
#help Remove-NavContainerSession    -full
#help Enter-NavContainer            -full
#help Open-NavContainer             -full
#help Wait-NavContainerReady        -full
#help Import-ObjectsToNavContainer  -full
#help Compile-ObjectsInNavContainer -full
#help Export-NavContainerObjects    -full
#help Create-MyOriginalFolder       -full
#help Create-MyDeltaFolder          -full
#help Convert-Txt2Al                -full
#help Convert-ModifiedObjectsToAl   -full
#help Publish-NavContainerApp       -full
#help Sync-NavContainerApp          -full
#help Install-NavContainerApp       -full
#help Uninstall-NavContainerApp     -full
#help Unpublish-NavContainerApp     -full
#help Get-NavContainerAppInfo       -full
#help Install-NAVSipCryptoProviderFromNavContainer -full
#help Replace-NavServerContainer    -full
#help Recreate-NavServerContainer   -full

Clear-Variable -Name "password"
