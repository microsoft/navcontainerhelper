Remove-Module NavContainerHelper -ErrorAction Ignore
Import-Module (Join-Path $PSScriptRoot "NavContainerHelper.psm1") -DisableNameChecking

clear
Write-Host -ForegroundColor Yellow "Welcome to the Nav Container Helper PowerShell Prompt"
Write-Host
Write-Host -ForegroundColor Yellow "Container info functions"
Write-Host "Get-NavContainerNavVersion    Get Nav version from Nav Container"
Write-Host "Get-NavContainerImageName     Get ImageName from Nav container"
Write-Host "Get-NavContainerGenericTag    Get Nav generic image tag from Nav container"
Write-Host "Get-NavContainerOsVersion     Get OS version from Nav container"
Write-Host "Get-NavContainerLegal         Get Legal link from Nav container"
Write-Host "Get-NavContainerCountry       Get Localization version from Nav Container"
Write-Host
Write-Host -ForegroundColor Yellow "Container handling functions"
Write-Host "New-CSideDevContainer         Create new C/SIDE development container"
Write-Host "Remove-CSideDevContainer      Remove C/SIDE development container"
Write-Host "Replace-NavServerContainer    Replace navserver (primary) container"
Write-Host "Recreate-NavServerContainer   Recreate navserver (primary) container"
Write-Host "Enter-NavContainer            Enter Nav container session"
Write-Host "Open-NavContainer             Open Nav container in new window"
Write-Host "Wait-NavContainerReady        Wait for Nav Container to become ready"
Write-Host
Write-Host -ForegroundColor Yellow "Object handling functions"
Write-Host "Import-ObjectsToNavContainer  Import objects from .txt or .fob file"
Write-Host "Compile-ObjectsInNavContainer Compile objects"
Write-Host "Export-NavContainerObjects    Export objects from Nav container"
Write-Host "Create-MyOriginalFolder       Create folder with the original objects for modified objects"
Write-Host "Create-MyDeltaFolder          Create folder with deltas for modified objects"
Write-Host "Convert-Txt2Al                Convert deltas folder to al folder"
Write-Host "Convert-ModifiedObjectsToAl   Export objects, create baseline, create deltas and convert to .al files"
Write-Host
Write-Host -ForegroundColor Yellow "App handling functions"
Write-Host "Publish-NavContainerApp       Publish App to Nav container"
Write-Host "Sync-NavContainerApp          Sync App in Nav container"
Write-Host "Install-NavContainerApp       Install App in Nav container"
Write-Host "Uninstall-NavContainerApp     Uninstall App from Nav container"
Write-Host "Unpublish-NavContainerApp     Unpublish App from Nav container"
Write-Host "Get-NavContainerAppInfo       Get info about installed apps from Nav Container"
Write-Host "Get-NavSipCryptoProvider      Get Nav Sip Crypto Provider from container to sign extensions"
Write-Host
