<# 
 .Synopsis
  Create a VS Code AL Project Folder based on a Container
 .Description
  Export all objects from a container, convert them to AL and establish the necessary project files.
  The container needs to be started with -includeAL, which ensures that the .net used by the baseapp are available in a folder.
 .Parameter containerName
  Name of the container from which you want to create the AL Project folder
 .Parameter alProjectFolder
  The alProjectFolder will contain the AL project upon successful completion of this function.
  The content of the folder will be removed.
  This folder doesn't need to be shared with the container, but if you want to use Compile-AppInNavContainer, it might be a good idea to share it.
 .Parameter id
  This parameter specifies the ID of the AL app to be placed in app.json. Default is a new GUID.
 .Parameter name
  This parameter specifies the name of the AL app to be placed in app.json. Default is the container name.
 .Parameter publisher
  This parameter specifies the publisher of the AL app to be placed in app.json. Default is Default Publisher.
 .Parameter version
  This parameter specifies the version of the AL app to be placed in app.json. Default is 1.0.0.0.
 .Parameter addGIT
  Specify 
 .Parameter useBaseLine
  Specify this switch if you want to use the AL BaseLine, which was created when creating the container with -includeAL.
  The baseline AL objects are added to "C:\ProgramData\NavContainerHelper\Extensions\Original-<version>-<country>-al" and will contain AL files for the C/AL objects in the container at create time.
 .Example
  $alProjectFolder = "C:\ProgramData\NavContainerHelper\AL\BaseApp"
  Create-AlProjectFolderFromNavContainer -containerName alContainer `
                                         -alProjectFolder $alProjectFolder `
                                         -name "myapp" `
                                         -publisher "Freddy Kristiansen" `
                                         -version "1.0.0.0" `
                                         -AddGIT `
                                         -useBaseLine
#>
function Create-AlProjectFolderFromNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $containerName, 
        [Parameter(Mandatory=$true)]
        [string] $alProjectFolder,
        [string] $id = [GUID]::NewGuid().ToString(),
        [string] $name = $containerName,
        [string] $publisher = "Default Publisher",
        [string] $version = "1.0.0.0",
        [switch] $AddGIT,
        [switch] $useBaseLine,
        [ScriptBlock] $alFileStructure
    )

    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $ver = [System.Version]($navversion.split('-')[0])
    $alFolder   = Join-Path $ExtensionsFolder "Original-$navversion-al"
    $dotnetAssembliesFolder = Join-Path $ExtensionsFolder "$containerName\.netPackages"

    if (!(Test-Path $alFolder -PathType Container) -or !(Test-Path $dotnetAssembliesFolder -PathType Container)) {
        throw "Container $containerName was not started with -includeAL"
    }

    # Empty Al Project Folder
    if (Test-Path -Path $alProjectFolder -PathType Container) {
        Remove-Item -Path "$alProjectFolder\*" -Recurse -Force
    }
    else {
        New-Item -Path $AlProjectFolder -ItemType Directory | Out-Null
    }

    if ($useBaseLine) {
        Copy-AlSourceFiles -Path "$alFolder\*" -Destination $AlProjectFolder -Recurse -alFileStructure $alFileStructure
    }
    else {
        Convert-ModifiedObjectsToAl -containerName $containerName -doNotUseDeltas -alProjectFolder $AlProjectFolder -alFileStructure $alFileStructure
    }

    $appJsonFile = Join-Path $AlProjectFolder "app.json"
    if ($ver.Major -eq 15) {
        $appJson = @{ 
            "id" = $id
            "name" = $name
            "publisher" = $publisher
            "version" = $version
            "brief" = ""
            "description" = ""
            "privacyStatement" = ""
            "EULA" = ""
            "help" = ""
            "url" = ""
            "logo" = ""
            "dependencies" = @(@{
                "appId" = "63ca2fa4-4f03-4f2b-a480-172fef340d3f"
                "publisher" = "Microsoft"
                "name" = "System Application"
                "version" = "1.0.0.0"
            })
            "screenshots" = @()
            "platform" = "15.0.0.0"
            "idRanges" = @()
            "showMyCode" = $true
            "runtime" = "4.0"
            "target" = "OnPrem"
        }
    }
    else {
        $appJson = @{ 
            "id" = $id
            "name" = $name
            "publisher" = $publisher
            "version" = $version
            "brief" = ""
            "description" = ""
            "privacyStatement" = ""
            "EULA" = ""
            "help" = ""
            "url" = ""
            "logo" = ""
            "dependencies" = @()
            "screenshots" = @()
            "platform" = "14.0.0.0"
            "idRanges" = @()
            "showMyCode" = $true
            "runtime" = "3.0"
            "target" = "Internal"
        }
    }
    Set-Content -Path $appJsonFile -Value ($appJson | ConvertTo-Json)

    $dotnetPackagesFolder = Join-Path $AlProjectFolder ".netpackages"
    New-Item -Path $dotnetPackagesFolder -ItemType Directory -Force | Out-Null

    $alPackagesFolder = Join-Path $AlProjectFolder ".alpackages"
    New-Item -Path $alPackagesFolder -ItemType Directory -Force | Out-Null

    $vscodeFolder = Join-Path $AlProjectFolder ".vscode"
    New-Item -Path $vscodeFolder -ItemType Directory -Force | Out-Null

    $settingsJsonFile = Join-Path $vscodeFolder "settings.json"
    $settingsJson = @{
        "al.enableCodeAnalysis" = $false
        "al.enableCodeActions" = $false
        "al.incrementalBuild" = $true
        "al.packageCachePath" = ".alpackages"
        "al.assemblyProbingPaths" = @(".netpackages", $dotnetAssembliesFolder)
        "editor.codeLens" = $false
    }
    Set-Content -Path $settingsJsonFile -Value ($settingsJson | ConvertTo-Json)
    
    $launchJsonFile = Join-Path $vscodeFolder "launch.json"
    $config = Get-NavContainerServerConfiguration -ContainerName $containerName
    if ($config.DeveloperServicesSSLEnabled -eq "true") {
        $devserverUrl = "https://$containerName"
    }
    else {
        $devserverUrl = "http://$containerName"
    }
    if ($config.ClientServicesCredentialType -eq "Windows") {
        $authentication = "Windows"
    }
    else {
        $authentication = "UserPassword"
    }
    $launchJson = @{
        "version" = "0.2.0"
        "configurations" = @( @{
            "type" = "al"
            "request" = "launch"
            "name" = "$containerName"
            "server" = $devserverUrl
            "port" = [int]($config.DeveloperServicesPort)
            "serverInstance" = $config.ServerInstance
            "authentication" = $authentication
            "breakOnError" = $true
            "launchBrowser" = $true
        } )
    }
    Set-Content -Path $launchJsonFile -Value ($launchJson | ConvertTo-Json)

    if ($addGit) {
        Write-Host "Initializing Git repository"

        $gitIgnoreFile = Join-Path $AlProjectFolder ".gitignore"
        Set-Content -Path $gitIgnoreFile -Value ".vscode`r`n*.app"

        $oldLocation = Get-Location
        Set-Location $AlProjectFolder
        & git init
        Write-Host "Adding files"
        & git add .
        & git gc --auto --quiet
        Write-Host "Committing files"
        & git commit -m "$containerName" | Out-Null
        Set-Location $oldLocation
    }
    
    Write-Host -ForegroundColor Green "Al Project Folder Created"
}
Set-Alias -Name Create-AlProjectFolderFromBcContainer -Value Create-AlProjectFolderFromNavContainer
Export-ModuleMember -Function Create-AlProjectFolderFromNavContainer -Alias Create-AlProjectFolderFromBcContainer

