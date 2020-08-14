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
  This folder doesn't need to be shared with the container, but if you want to use Compile-AppInBcContainer, it might be a good idea to share it.
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
  The baseline AL objects are added to "C:\ProgramData\BcContainerHelper\Extensions\Original-<version>-<country>-al" and will contain AL files for the C/AL objects in the container at create time.
 .Parameter alFileStructure
  Specify a function, which will determine the location of the individual al source files
 .Parameter runTxt2AlInContainer
  Specify a foreign container in which you want to run the txt2al tool
 .Parameter useBaseAppProperties
  Specify to retrieve app properties from base app actually installed in container
 .Parameter credential
  Credentials are needed to download the app if you do not use the baseline
 .Example
  $alProjectFolder = "C:\ProgramData\BcContainerHelper\AL\BaseApp"
  Create-AlProjectFolderFromBcContainer -containerName alContainer `
                                         -alProjectFolder $alProjectFolder `
                                         -name "myapp" `
                                         -publisher "Freddy Kristiansen" `
                                         -version "1.0.0.0" `
                                         -AddGIT `
                                         -useBaseLine
#>
function Create-AlProjectFolderFromBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $alProjectFolder,
        [string] $id = [GUID]::NewGuid().ToString(),
        [string] $name = $containerName,
        [string] $publisher = "Default Publisher",
        [string] $version = "1.0.0.0",
        [switch] $AddGIT,
        [switch] $useBaseLine,
        [ScriptBlock] $alFileStructure,
        [string] $runTxt2AlInContainer = $containerName,
        [switch] $useBaseAppProperties,
        [PSCredential] $credential = $null
    )

    $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
    $ver = [System.Version]($navversion.split('-')[0])
    $alFolder   = Join-Path $ExtensionsFolder "Original-$navversion-al"
    $dotnetAssembliesFolder = Join-Path $ExtensionsFolder "$containerName\.netPackages"

    if (($useBaseLine -and !(Test-Path $alFolder -PathType Container)) -or !(Test-Path $dotnetAssembliesFolder -PathType Container)) {
        throw "Container $containerName was not started with -includeAL (or -doNotExportObjectsAsText was specified)"
    }

    # Empty Al Project Folder
    if (Test-Path -Path $alProjectFolder -PathType Container) {
        if (Test-Path -Path (Join-Path $alProjectFolder "*")) {
            if (Test-Path -Path (Join-Path $alProjectFolder "app.json")) {
                Remove-Item -Path (Join-Path $alProjectFolder "*") -Recurse -Force
            }
            else {
                throw "The directory '$alProjectFolder' already exists, and it doesn't seem to be an AL project folder, please remove the folder manually."
            }
        }
    }
    else {
        New-Item -Path $AlProjectFolder -ItemType Directory | Out-Null
    }

    if ($useBaseLine) {
        Copy-AlSourceFiles -Path "$alFolder\*" -Destination $AlProjectFolder -Recurse -alFileStructure $alFileStructure
    }
    elseif ($ver.Major -ge 15) {
        $id = [Guid]::NewGuid().Guid
        $appFile = Join-Path $ExtensionsFolder "BaseApp-$id.app"
        $appFolder = Join-Path $ExtensionsFolder "BaseApp-$id"
        $myAlFolder = Join-Path $ExtensionsFolder "al-$id"
        try {
            $appName = "Base Application"
            if ($ver -lt [Version]("15.0.35659.0")) {
                $appName = "BaseApp"
            }
            $baseapp = Get-BcContainerAppInfo -containerName $containerName | Where-Object { $_.Name -eq $appName }
            Get-BcContainerApp -containerName $containerName `
                               -publisher $baseapp.Publisher `
                               -appName $baseapp.Name `
                               -appVersion $baseapp.Version `
                               -appFile $appFile `
                               -credential $credential
        
            Extract-AppFileToFolder -appFilename $appFile -appFolder $appFolder
            'layout','src','translations' | ForEach-Object {
                if (Test-Path (Join-Path $appFolder $_)) {
                    Copy-Item -Path (Join-Path $appFolder $_) -Destination $myAlFolder -Recurse -Force
                }
            }

            Copy-AlSourceFiles -Path "$myAlFolder\*" -Destination $AlProjectFolder -Recurse -alFileStructure $alFileStructure
        }
        finally {    
            Remove-Item -Path $myAlFolder -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $appFolder -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $appFile -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Convert-ModifiedObjectsToAl -containerName $containerName -doNotUseDeltas -alProjectFolder $AlProjectFolder -alFileStructure $alFileStructure -runTxt2AlInContainer $runTxt2AlInContainer
    }

    $appJsonFile = Join-Path $AlProjectFolder "app.json"
    if ($useBaseLine -and $ver -ge [Version]("15.0.35528.0")) {
        $appJson = Get-Content "$alFolder\app.json" | ConvertFrom-Json

        if (-not $useBaseAppProperties) {
            $appJson.Id = $id
            $appJson.Name = $name
            $appJson.Publisher = $publisher
            $appJson.Version = $version
        }

        if ([bool]($appJson.PSObject.Properties.name -eq "Logo")) {
            try {
                Copy-Item -Path (Join-Path $alFolder $appJson.Logo) -Destination (Join-Path $alProjectFolder $appJson.Logo) -Force
            }
            catch {
                $appJson.Logo = ""
            }
        }

    } elseif ($ver.Major -ge  15) {
        
        if ($useBaseAppProperties) {
            $appName = "Base Application"
            if ($ver -lt [Version]("15.0.35659.0")) {
                $appName = "BaseApp"
            }
            $baseapp = Get-BcContainerAppInfo -containerName $containerName | Where-Object { $_.Name -eq $appName }
            if ($baseapp) {
                $id = $baseapp.AppId
                $name = $baseapp.Name
                $publisher = $baseapp.Publisher
                $version = $baseapp.Version
            }
            else {
                throw "BaseApp not found"
            }
        }
        if ($ver -ge [Version]("15.0.35528.0")) {
            $sysAppVer = "$($ver.Major).0.0.0"
        }
        else {
            $sysAppVer = "1.0.0.0"
        }
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
                "version" = $sysAppVer
            })
            "screenshots" = @()
            "platform" = "$($ver.Major).0.0.0"
            "idRanges" = @()
            "showMyCode" = $true
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
    $config = Get-BcContainerServerConfiguration -ContainerName $containerName
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
        Add-GitToAlProjectFolder -alProjectFolder $alProjectFolder -commitMessage $containerName
    }
    
    Write-Host -ForegroundColor Green "Al Project Folder Created"
}
Set-Alias -Name Create-AlProjectFolderFromNavContainer -Value Create-AlProjectFolderFromBcContainer
Export-ModuleMember -Function Create-AlProjectFolderFromBcContainer -Alias Create-AlProjectFolderFromNavContainer

