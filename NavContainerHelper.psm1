Set-StrictMode -Version 2.0
$verbosePreference = "SilentlyContinue"
$warningPreference = "SilentlyContinue"
$errorActionPreference = 'Stop'

$demoFolder = $PSScriptRoot
$extensionsFolder = Join-Path $demoFolder "Extensions"
New-Item -Path $extensionsFolder -ItemType Container -Force -ErrorAction Ignore
$containerDemoFolder = "C:\DEMO"
$containerExtensionsFolder = "C:\DEMO\Extensions"

$sessions = @{}

function HelperGetContainersForDynParam {
    $ParameterName = 'containerName'
        
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $ParameterAttribute.Mandatory = $true
    $ParameterAttribute.Position = 0

    $AttributeCollection.Add($ParameterAttribute)

    $arrSet =  docker ps -a --format '{{.Names}}'
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
    $AttributeCollection.Add($ValidateSetAttribute)

    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
    $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
    return $RuntimeParameterDictionary 
}

function HelperGetContainersAndImagesForDynParam {
    $ParameterName = 'containerOrImageName'
        
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $ParameterAttribute.Mandatory = $true
    $ParameterAttribute.Position = 0

    $AttributeCollection.Add($ParameterAttribute)

    [array]$arrSet =  docker ps -a --format '{{.Names}}'
    $arrSet += (docker images --format "{{.Repository}}:{{.Tag}}") | Where-Object { $_.Contains("/dynamics-nav:") }

    if ($arrSet) {
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
    }

    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
    $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
    return $RuntimeParameterDictionary 
}

function Log([string]$line, [string]$color = "Gray") { 
    Write-Host -ForegroundColor $color $line
}

function Get-DefaultAdminPassword {
    if (!(Test-Path "$demoFolder\settings.ps1")) {
        throw "You need to specify adminPassword if you are not using the scripts inside the Nav on Azure DEMO VMs"
    }
    . "$demoFolder\settings.ps1"
    $adminPassword
}

function Get-DefaultVmAdminUsername {
    if (Test-Path "$demoFolder\settings.ps1") {
        . "$demoFolder\settings.ps1"
        $vmAdminUsername
    } else {
        "vmadmin"
    }
}

function Get-NavContainerSession {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']
        $containerId = Get-ContainerId -containerName $containerName

        if (!($sessions.ContainsKey($containerId))) {
            $session = New-PSSession -ContainerId $containerId -RunAsAdministrator
            Invoke-Command -Session $session -ScriptBlock {
                $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
                if (Test-Path $serviceTierFolder -PathType Container) {
                    Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1" -wa SilentlyContinue
                }
                
                $roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
                if (Test-Path $roleTailoredClientFolder -PathType Container) {
                    $NavIde = Join-Path $roleTailoredClientFolder "finsql.exe"
                    Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1" -wa SilentlyContinue
                    Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
                    Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Tools.psd1" -wa SilentlyContinue
                    Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Model.Tools.psd1" -wa SilentlyContinue
                    $txt2al = $NavIde.replace("finsql.exe","txt2al.exe")
                    if (!(Test-Path $txt2al)) {
                        $txt2al = ""
                    }
                }

                . c:\run\HelperFunctions.ps1 | Out-Null
                cd c:\run
            }
            $sessions.Add($containerId, $session)
        }
        $sessions[$containerId]
    }
}

function Remove-NavContainerSession {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']
        $containerId = Get-ContainerId -containerName $containerName

        if ($sessions.ContainsKey($containerId)) {
            $session = $sessions[$containerId]
            Remove-PSSession -Session $session
            $sessions.Remove($containerId)
        }
    }
}

function Download-File {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$sourceUrl,
        [Parameter(Mandatory=$true)]
        [string]$destinationFile
    )

    Write-Host "Downloading $destinationFile"
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}

function Enter-NavContainer {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']

        $session = Get-NavContainerSession $containerName
        Enter-PSSession -Session $session
    }
}

function Open-NavContainer {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']

        Start-Process "cmd.exe" @("/C";"docker exec -it $containerName powershell -noexit C:\Run\prompt.ps1")
    }
}

function Get-NavContainerNavVersion {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersAndImagesForDynParam)}

    Process {
        $containerOrImageName = $PsBoundParameters['containerOrImageName']
        docker inspect --format='{{.Config.Labels.version}}-{{.Config.Labels.country}}' $containerOrImageName
    }
}

function Get-NavContainerImageName {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']

        docker inspect --format='{{.Config.Image}}' $containerName
    }
}

function Get-NavContainerGenericTag {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersAndImagesForDynParam)}

    Process {
        $containerOrImageName = $PsBoundParameters['containerOrImageName']

        docker inspect --format='{{.Config.Labels.tag}}' $containerOrImageName
    }
}

function Get-NavContainerOsVersion {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersAndImagesForDynParam)}

    Process {
        $containerOrImageName = $PsBoundParameters['containerOrImageName']

        # returns empty with generic tag 0.0.2.3 or earlier
        docker inspect --format='{{.Config.Labels.osversion}}' $containerOrImageName
    }
}

function Get-NavContainerLegal {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersAndImagesForDynParam)}

    Process {
        $containerOrImageName = $PsBoundParameters['containerOrImageName']

        docker inspect --format='{{.Config.Labels.legal}}' $containerOrImageName
    }
}

function Get-NavContainerCountry {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersAndImagesForDynParam)}

    Process {
        $containerOrImageName = $PsBoundParameters['containerOrImageName']

        docker inspect --format='{{.Config.Labels.country}}' $containerOrImageName
    }
}

function Get-ContainerName {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerId
    )

    docker ps --format='{{.Names}}' -a --filter "id=$containerId"
}

function Test-Container {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    Process {
        $exist = $false;
        docker ps --filter name="$containerName" -a -q --no-trunc | % {
            $name = Get-ContainerName -containerId $_
            if ($name -eq $containerName) {
                $exist = $true
            }
        }
        $exist
    }
}

function Get-ContainerId {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']

        $id = ""
        docker ps --filter name="$containerName" -a -q --no-trunc | % {
            $name = Get-ContainerName -containerId $_
            if ($name -eq $containerName) {
                $id = $_
            }
        }
        $id
    }
}

function New-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name, 
        [Parameter(Mandatory=$true)]
        [string]$TargetPath, 
        [string]$WorkingDirectory = "", 
        [string]$IconLocation = "", 
        [string]$Arguments = "",
        [string]$FolderName = "Desktop"
    )
    $filename = Join-Path ([Environment]::GetFolderPath($FolderName)) "$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }

    $Shell =  New-object -comobject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($filename)
    $Shortcut.TargetPath = $TargetPath
    if (!$WorkingDirectory) {
        $WorkingDirectory = Split-Path $TargetPath
    }
    $Shortcut.WorkingDirectory = $WorkingDirectory
    if ($Arguments) {
        $Shortcut.Arguments = $Arguments
    }
    if ($IconLocation) {
        $Shortcut.IconLocation = $IconLocation
    }
    $Shortcut.save()
}

function Remove-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$FolderName = "Desktop"
    )
    $filename = Join-Path ([Environment]::GetFolderPath($FolderName)) "$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }
}

function New-CSideDevContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$devImageName = "", 
        [string]$licenseFile = "$demoFolder\license.flf",
        [string]$vmAdminUsername = (Get-DefaultVmAdminUsername), 
        [string]$adminPassword = (Get-DefaultAdminPassword),
        [string]$memoryLimit = "4G"
    )

    Write-Host "Creating C/SIDE developer container $containerName"

    if ($containerName -eq "navserver") {
        throw "You should not create a CSide development container called navserver. Use Replace-NavServerContainer to replace the navserver container."
    }
  
    if (!(Test-Path $licenseFile)) {
        throw "License file '$licenseFile' must exist in order to create a Developer Server Container."
    }
    $containerLicenseFile = $licenseFile.Replace("$demoFolder\", "$containerDemoFolder\")

    if ($devImageName -eq "") {
        if (!(Test-Container -containerName navserver)) {
            throw "You need to specify devImageName if you are not using the scripts inside the Nav on Azure DEMO VMs"
        }
        $devImageName = Get-NavContainerImageName -containerName navserver
        $devCountry = Get-NavContainerCountry -containerOrImageName navserver
    } else {
        $imageId = docker images -q $devImageName
        if (!($imageId)) {
            Write-Host "Pulling docker Image $devImageName"
            docker pull $devImageName
        }
        $devCountry = Get-NavContainerCountry -containerOrImageName $devImageName
    }

    if (Test-Container -containerName $containerName) {
        Remove-CSideDevContainer $containerName
    }

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $programFilesFolder = Join-Path $containerFolder "Program Files"
    New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    $locale = Get-LocaleFromCountry $devCountry
    $navversion = Get-NavContainerNavversion -containerOrImageName $devImageName
    Write-Host "Image Name: $devImageName"
    Write-Host "NAV Version: $navversion"

    'sqlcmd -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0"
    ' | Set-Content -Path "$myfolder\AdditionalSetup.ps1"

    if (Test-Path $programFilesFolder) {
        Remove-Item $programFilesFolder -Force -Recurse -ErrorAction Ignore
    }
    New-Item $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    
    ('Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
    $destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
    $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
    [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "'+$containerName+'"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServerInstance""]").value="NAV"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServicesCertificateValidationEnabled""]").value="false"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesPort""]").value="$publicWinClientPort"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ACSUri""]").value = ""
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""DnsIdentity""]").value = "$dnsIdentity"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCredentialType""]").value = "$Auth"
    $clientUserSettings.Save("$destFolder\ClientUserSettings.config")
    ') | Add-Content -Path "$myfolder\AdditionalSetup.ps1"

    Write-Host "Creating container $containerName from image $devImageName"
    $id = docker run `
                 --name $containerName `
                 --hostname $containerName `
                 --env accept_eula=Y `
                 --env useSSL=N `
                 --env auth=Windows `
                 --env username=$vmAdminUsername `
                 --env password=$adminPassword `
                 --env ExitOnError=N `
                 --env locale=$locale `
                 --env licenseFile="$containerLicenseFile" `
                 --memory $memoryLimit `
                 --volume "${demoFolder}:$containerDemoFolder" `
                 --volume "${myFolder}:C:\Run\my" `
                 --volume "${programFilesFolder}:C:\navpfiles" `
                 --restart always `
                 --detach `
                 $devImageName

    Wait-NavContainerReady $containerName

    Write-Host "Create Desktop Shortcuts for $containerName"
    $winClientFolder = (Get-Item "$programFilesFolder\*\RoleTailored Client").FullName
    
    $ps = '$customConfigFile = Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "CustomSettings.config"
    [System.IO.File]::ReadAllText($customConfigFile)'
    [xml]$customConfig = docker exec $containerName powershell $ps
    $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
    $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
    $databaseServer = "$containerName"
    if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

    New-DesktopShortcut -Name "$containerName Web Client" -TargetPath "http://${containerName}/NAV/" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    New-DesktopShortcut -Name "$containerName Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe"
    New-DesktopShortcut -Name "$containerName CSIDE" -TargetPath "$WinClientFolder\finsql.exe" -Arguments "servername=$databaseServer, Database=$databaseName, ntauthentication=yes"
    New-DesktopShortcut -Name "$containerName Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName cmd"
    New-DesktopShortcut -Name "$containerName PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1"

    $originalFolder = Join-Path $ExtensionsFolder "Original-$navversion"
    $newSyntaxFolder = "$originalFolder-newsyntax"

    if (!(Test-Path $originalFolder)) {
        
        $session = Get-NavContainerSession -containerName $containerName
        $txt2al = Invoke-Command -Session $session -ScriptBlock { $txt2al }

        if ($txt2al) {
            Export-NavContainerObjects -containerName $containerName `
                                       -objectsFolder $newSyntaxFolder `
                                       -adminPassword $adminPassword `
                                       -ExportToNewSyntax $true `
        }
            
        Export-NavContainerObjects -containerName $containerName `
                                   -objectsFolder $originalFolder `
                                   -adminPassword $adminPassword `
                                   -ExportToNewSyntax $false
    }

    Write-Host -ForegroundColor Green "C/SIDE developer container $containerName successfully created"
}

function Remove-CSideDevContainer {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']

        if ($containerName -eq "navserver") {
            throw "You should not remove the navserver container. Use Replace-NavServerContainer to replace the navserver container."
        }

        if (Test-Container -containerName $containerName) {
            $containerId = Get-ContainerId -containerName $containerName
            Write-Host "Removing container $containerName"
            docker rm $containerId -f | Out-Null
            $containerFolder = Join-Path $ExtensionsFolder $containerName
            Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction Ignore
            Write-Host "Removing Desktop Shortcuts for container $containerName"
            Remove-DesktopShortcut -Name "$containerName Web Client"
            Remove-DesktopShortcut -Name "$containerName Windows Client"
            Remove-DesktopShortcut -Name "$containerName CSIDE"
            Remove-DesktopShortcut -Name "$containerName Command Prompt"
            Remove-DesktopShortcut -Name "$containerName PowerShell Prompt"
            Remove-NavContainerSession $containerName
            Write-Host -ForegroundColor Green "Successfully removed container $containerName"
        }
    }
}

function Wait-NavContainerReady {
    [CmdletBinding()]
    Param
    ()

    DynamicParam {return (HelperGetContainersForDynParam)}

    Process {
        $containerName = $PsBoundParameters['containerName']

        Write-Host "Waiting for container $containerName to be ready, this shouldn't take more than a few minutes"
        Write-Host "Time:          ½              1              ½              2"
        $cnt = 150
        $log = ""
        do {
            Write-Host -NoNewline "."
            Start-Sleep -Seconds 2
            $logs = docker logs $containerName
            if ($logs) { $log = [string]::Join(" ",$logs) }
            if ($log.Contains("<ScriptBlock>")) { $cnt = 0 }
        } while ($cnt-- -gt 0 -and !($log.Contains("Ready for connections!")))
        Write-Host "Ready"
    }
}

function Get-LocaleFromCountry {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$country
    )

    switch ($country) {
    "finus" { "en-US" }
    "finca" { "en-CA" }
    "fingb" { "en-GB" }
    "findk" { "da-DK" }
    "at"    { "de-AT" }
    "au"    { "en-AU" } 
    "be"    { "nl-BE" }
    "ch"    { "de-CH" }
    "cz"    { "cs-CZ" }
    "de"    { "de-DE" }
    "dk"    { "da-DK" }
    "es"    { "es-ES" }
    "fi"    { "fi-FI" }
    "fr"    { "fr-FR" }
    "gb"    { "en-GB" }
    "in"    { "en-IN" }
    "is"    { "is-IS" }
    "it"    { "it-IT" }
    "na"    { "en-US" }
    "nl"    { "nl-NL" }
    "no"    { "nb-NO" }
    "nz"    { "en-NZ" }
    "ru"    { "ru-RU" }
    "se"    { "sv-SE" }
    "w1"    { "en-US" }
    "us"    { "en-US" }
    "mx"    { "es-MX" }
    "ca"    { "en-CA" }
    "dech"  { "de-CH" }
    "frbe"  { "fr-BE" }
    "frca"  { "fr-CA" }
    "frch"  { "fr-CH" }
    "itch"  { "it-CH" }
    "nlbe"  { "nl-BE" }
    default { "en-US" }
    }
}

function Export-NavContainerObjects {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$objectsFolder, 
        [string]$adminPassword = (Get-DefaultAdminPassword), 
        [string]$filter = "", 
        [bool]$exportToNewSyntax = $true
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($filter, $objectsFolder, $adminPassword)

        $objectsFile = "$objectsFolder.txt"
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
        Remove-Item -Path $objectsFolder -Force -Recurse -ErrorAction Ignore
        if ($exportToNewSyntax) {
            Write-Host "Export Objects as new format to $objectsFile"
        } else {
            Write-Host "Export Objects to $objectsFile"
        }

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

        if ($exportToNewSyntax) {
            Export-NAVApplicationObject -DatabaseName $databaseName `
                                        -Path $objectsFile `
                                        -DatabaseServer $databaseServer `
                                        -Force `
                                        -Filter "$filter" `
                                        -ExportToNewSyntax `
                                        -Username "sa" `
                                        -Password $adminPassword | Out-Null
        } else {
            Export-NAVApplicationObject -DatabaseName $databaseName `
                                        -Path $objectsFile `
                                        -DatabaseServer $databaseServer `
                                        -Force `
                                        -Filter "$filter" `
                                        -Username "sa" `
                                        -Password $adminPassword | Out-Null
        }
        Write-Host "Split $objectsFile to $objectsFolder"
        New-Item -Path $objectsFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
        Split-NAVApplicationObjectFile -Source $objectsFile `
                                       -Destination $objectsFolder
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
    
    }  -ArgumentList $filter, $objectsFolder.Replace($ExtensionsFolder, $containerExtensionsFolder), $adminPassword
}

function Create-MyOriginalFolder {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$originalFolder, 
        [Parameter(Mandatory=$true)]
        [string]$modifiedFolder, 
        [Parameter(Mandatory=$true)]
        [string]$myoriginalFolder
    )

    Write-Host "Copy original objects to $myoriginalFolder for all objects that are modified"
    Remove-Item -Path $myoriginalFolder -Recurse -Force -ErrorAction Ignore
    New-Item -Path $myoriginalFolder -ItemType Directory | Out-Null
    Get-ChildItem $modifiedFolder | % {
        $Name = $_.Name
        $OrgName = Join-Path $myOriginalFolder $Name
        $TxtFile = Join-Path $originalFolder $Name
        if (Test-Path -Path $TxtFile) {
            Copy-Item -Path $TxtFile -Destination $OrgName
        }
    }
}

function Create-MyDeltaFolder {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$modifiedFolder, 
        [Parameter(Mandatory=$true)]
        [string]$myOriginalFolder, 
        [Parameter(Mandatory=$true)]
        [string]$myDeltaFolder
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($modifiedFolder, $myOriginalFolder, $myDeltaFolder)

        Write-Host "Compare modified objects with original objects in $myOriginalFolder and create Deltas in $myDeltaFolder"
        Remove-Item -Path $myDeltaFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myDeltaFolder -ItemType Directory | Out-Null
        Compare-NAVApplicationObject -OriginalPath $myOriginalFolder -ModifiedPath $modifiedFolder -DeltaPath $myDeltaFolder | Out-Null

        Write-Host "Rename new objects to .TXT"
        Get-ChildItem $myDeltaFolder | % {
            $Name = $_.Name
            if ($Name.ToLowerInvariant().EndsWith(".delta")) {
                $BaseName = $_.BaseName
                $OrgName = Join-Path $myOriginalFolder "${BaseName}.TXT"
                if (!(Test-Path -Path $OrgName)) {
                    Rename-Item -Path $_.FullName -NewName "${BaseName}.TXT"
                }
            }
        }
    } -ArgumentList $modifiedFolder.Replace($ExtensionsFolder, $containerExtensionsFolder), $myOriginalFolder.Replace($ExtensionsFolder, $containerExtensionsFolder), $myDeltaFolder.Replace($ExtensionsFolder, $containerExtensionsFolder)
}

function Convert-Txt2Al {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$myDeltaFolder, 
        [Parameter(Mandatory=$true)]
        [string]$myAlFolder, 
        [int]$startId=50100
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($myDeltaFolder, $myAlFolder, $startId)

        if (!($txt2al)) {
            throw "You cannot run Convert-Txt2Al on this Nav Container"
        }
        Write-Host "Converting files in $myDeltaFolder to .al files in $myAlFolder with startId $startId"
        Remove-Item -Path $myAlFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myAlFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        Start-Process -FilePath $txt2al -ArgumentList "--source=""$myDeltaFolder"" --target=""$myAlFolder"" --rename --extensionStartId=$startId" -Wait -NoNewWindow
    
    } -ArgumentList $myDeltaFolder.Replace($ExtensionsFolder, $containerExtensionsFolder), $myAlFolder.Replace($ExtensionsFolder, $containerExtensionsFolder), $startId
}

function Convert-ModifiedObjectsToAl {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$adminPassword = (Get-DefaultAdminPassword), 
        [int]$startId = 50100
    )

    $session = Get-NavContainerSession -containerName $containerName
    $txt2al = Invoke-Command -Session $session -ScriptBlock { $txt2al }
    if (!($txt2al)) {
        throw "You cannot run Convert-ModifiedObjectsToAl on this Nav Container"
    }

    $suffix = "-newsyntax"

    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"
    $modifiedFolder   = Join-Path $ExtensionsFolder "$containerName\modified$suffix"
    $myOriginalFolder = Join-Path $ExtensionsFolder "$containerName\original$suffix"
    $myDeltaFolder    = Join-Path $ExtensionsFolder "$containerName\delta$suffix"
    $myAlFolder       = Join-Path $ExtensionsFolder "$containerName\al$suffix"

    Export-NavContainerObjects -containerName $containerName `
                               -objectsFolder $modifiedFolder `
                               -filter "modified=Yes" `
                               -adminPassword $adminPassword `
                               -exportToNewSyntax $true

    Create-MyOriginalFolder -originalFolder $originalFolder `
                            -modifiedFolder $modifiedFolder `
                            -myOriginalFolder $myOriginalFolder

    Create-MyDeltaFolder -containerName $containerName `
                         -modifiedFolder $modifiedFolder `
                         -myOriginalFolder $myOriginalFolder `
                         -myDeltaFolder $myDeltaFolder

    Convert-Txt2Al -containerName $containerName `
                   -myDeltaFolder $myDeltaFolder `
                   -myAlFolder $myAlFolder `
                   -startId $startId
    Start-Process $myAlFolder
    Write-Host ".al files created in $myAlFolder"
}

function Import-ObjectsToNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$objectsFile,
        [string]$adminPassword = (Get-DefaultAdminPassword)
    )

    $copyItem= (!($objectsFile.ToLowerInvariant().StartsWith($ExtensionsFolder.ToLowerInvariant())))
    if ($copyItem) {
        Write-Host "Copying objects to $ExtensionsFolder"
        $objectsFile = (Copy-Item -Path $objectsFile -Destination $ExtensionsFolder -PassThru -Force).FullName
    }

    try {
        $session = Get-NavContainerSession -containerName $containerName
        Invoke-Command -Session $session -ScriptBlock { Param($objectsFile, $adminPassword)
    
            $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
            [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
            $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
            $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
            $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
            if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
    
            Write-Host "Importing Objects from $objectsFile"
            Import-NAVApplicationObject -Path $objectsFile `
                                        -DatabaseName $databaseName `
                                        -DatabaseServer $databaseServer `
                                        -ImportAction Overwrite `
                                        -SynchronizeSchemaChanges Force `
                                        -Username "sa" `
                                        -Password $adminPassword `
                                        -NavServerName localhost `
                                        -NavServerInstance NAV `
                                        -NavServerManagementPort 7045 `
                                        -Confirm:$false
    
        } -ArgumentList $objectsFile.Replace($ExtensionsFolder, $containerExtensionsFolder), $adminPassword
        Write-Host -ForegroundColor Green "Objects successfully imported"
    } finally {
        if ($copyItem) {
            Remove-Item $objectsFile -Force
        }
    }

}

function Compile-ObjectsInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$filter = "modified=Yes", 
        [string]$adminPassword = (Get-DefaultAdminPassword)
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($filter, $adminPassword)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

        Write-Host "Compiling objects"
        Compile-NAVApplicationObject -Filter $filter `
                                     -DatabaseName $databaseName `
                                     -DatabaseServer $databaseServer `
                                     -Recompile `
                                     -SynchronizeSchemaChanges Force `
                                     -Username "sa" `
                                     -Password $adminPassword `
                                     -NavServerName localhost `
                                     -NavServerInstance NAV `
                                     -NavServerManagementPort 7045
    } -ArgumentList $filter, $adminPassword
    Write-Host -ForegroundColor Green "Objects successfully compiled"
}

function Publish-NavContainerApp {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$appFile,
        [string]$containerName = "navserver",
        [bool]$SkipVerification = $false 
    )
    
    $copyItem= (!($appFile.ToLowerInvariant().StartsWith($ExtensionsFolder.ToLowerInvariant())))
    if ($copyItem) {
        Write-Host "Copying app to $ExtensionsFolder"
        $appFile = (Copy-Item -Path $appFile -Destination $ExtensionsFolder -PassThru -Force).FullName
    }

    try {
        $session = Get-NavContainerSession -containerName $containerName
        Invoke-Command -Session $session -ScriptBlock { Param($appFile)
            Write-Host "Publishing app $appFile"
            Publish-NavApp -ServerInstance NAV -Path $appFile -SkipVerification:$SkipVerification
        } -ArgumentList $appFile.Replace($ExtensionsFolder, $containerExtensionsFolder)
        Write-Host -ForegroundColor Green "App successfully published"
    } finally {
        if ($copyItem) {
            Remove-Item $appFile -Force
        }
    }
}

function Sync-NavContainerApp {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$name,
        [Parameter(Mandatory=$true)]
        [string]$appFile,
        [string]$containerName = "navserver"
    )
    
    $copyItem= (!($appFile.ToLowerInvariant().StartsWith($ExtensionsFolder.ToLowerInvariant())))
    if ($copyItem) {
        Write-Host "Copying app to $ExtensionsFolder"
        $appFile = (Copy-Item -Path $appFile -Destination $ExtensionsFolder -PassThru -Force).FullName
    }

    try {
        $session = Get-NavContainerSession -containerName $containerName
        Invoke-Command -Session $session -ScriptBlock { Param($name, $appFile)
            Write-Host "Synchronizing app $appFile"
            Sync-NavApp -ServerInstance NAV -Name $name -Path $appFile
        } -ArgumentList $name, $appFile.Replace($ExtensionsFolder, $containerExtensionsFolder)
        Write-Host -ForegroundColor Green "App successfully synchronized"
    } finally {
        if ($copyItem) {
            Remove-Item $appFile -Force
        }
    }
}

function Install-NavContainerApp {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Installing app $appName"
        Install-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully installed"
}

function UnInstall-NavContainerApp {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Uninstalling app $appName"
        Uninstall-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully uninstalled"
}

function UnPublish-NavContainerApp {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Unpublishing app $appName"
        Unpublish-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully unpublished"
}

function Get-NavContainerAppInfo {
    Param(
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { 
        Get-NavAppInfo -ServerInstance NAV
    } 
}

function Get-NAVSipCryptoProvider {
    Param(
        [string]$containerName = "navserver"
    )

    Push-Location
    Set-Location c:\windows\system32
    RegSvr32 /u /s NavSip.dll
    Set-Location c:\windows\syswow64
    RegSvr32 /u /s NavSip.dll

    $msvcr120Path = "C:\Windows\System32\msvcr120.dll"
    if (!(Test-Path $msvcr120Path)) {
        Log "Copy msvcr120.dll from container $containerName"
        $msvcr120 = Invoke-Command -Session $session -ScriptBlock {
            Param($msvcr120Path) 
            [System.IO.File]::ReadAllBytes($msvcr120Path)
        } -ArgumentList $msvcr120Path
        [System.IO.File]::WriteAllBytes($msvcr120Path, $msvcr120)
    }

    Log "Copy NAV SIP crypto provider from container $containerName"
    $navSipPath = "C:\Windows\System32\NavSip.dll"
    $session = Get-NavContainerSession -containerName $containerName
    $navsip = Invoke-Command -Session $session -ScriptBlock {
        Param($navSipPath) 
        [System.IO.File]::ReadAllBytes($navSipPath)
    } -ArgumentList $navSipPath
    [System.IO.File]::WriteAllBytes($navSipPath, $navsip)
    $navSipPath = "C:\Windows\SysWow64\NavSip.dll"
    $session = Get-NavContainerSession -containerName $containerName
    $navsip = Invoke-Command -Session $session -ScriptBlock {
        Param($navSipPath) 
        [System.IO.File]::ReadAllBytes($navSipPath)
    } -ArgumentList $navSipPath
    [System.IO.File]::WriteAllBytes($navSipPath, $navsip)

    Set-Location c:\windows\system32
    RegSvr32 /s NavSip.dll
    Set-Location c:\windows\syswow64
    RegSvr32 /s NavSip.dll

    Pop-Location
}

function Replace-NavServerContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName, 
        [string]$certificatePfxUrl = "", 
        [string]$certificatePfxPassword = "", 
        [string]$publicDnsName = ""
    )

    $SetupNavContainerScript = "c:\demo\SetupNavContainer.ps1"
    $setupDesktopScript = "c:\demo\SetupDesktop.ps1"

    if (!((Test-Path $SetupNavContainerScript) -and (Test-Path $setupDesktopScript))) {
        throw "The Replace-NavServerContainer is designed to work inside the Nav on Azure DEMO VMs"
    }

    $newImageName = $imageName
    $newCertificatePfxUrl = $certificatePfxUrl
    $newCertificatePfxPassword = $certificatePfxPassword
    $newPublicDnsName = $publicDnsName

    . C:\DEMO\Settings.ps1

    if ($newCertificatePfxUrl -ne "" -and $newCertificatePfxPassword -ne "" -and $newPublicDnsName -ne "") {
        Download-File -sourceUrl $newCertificatePfxUrl -destinationFile "c:\demo\certificate.pfx"
    
        ('$certificatePfxPassword = "'+$newCertificatePfxPassword+'"
        $certificatePfxFile = "c:\demo\certificate.pfx"
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePfxFile, $certificatePfxPassword)
        $certificateThumbprint = $cert.Thumbprint
        Write-Host "Certificate File Thumbprint $certificateThumbprint"
        if (!(Get-Item Cert:\LocalMachine\my\$certificateThumbprint -ErrorAction SilentlyContinue)) {
            Write-Host "Import Certificate to LocalMachine\my"
            Import-PfxCertificate -FilePath $certificatePfxFile -CertStoreLocation cert:\localMachine\my -Password (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force) | Out-Null
        }
        $dnsidentity = $cert.GetNameInfo("SimpleName",$false)
        if ($dnsidentity.StartsWith("*")) {
            $dnsidentity = $dnsidentity.Substring($dnsidentity.IndexOf(".")+1)
        }
        Remove-Item $certificatePfxFile -force
        Remove-Item "c:\run\my\SetupCertificate.ps1" -force
        ') | Add-Content "c:\myfolder\SetupCertificate.ps1"
    } else {
        # Self signed cert. - use hostname as publicDnsName
        $newPublicDnsName = $hostname
    }

    $imageId = docker images -q $newImageName
    if (!($imageId)) {
        Write-Host "pulling $newImageName"
        docker pull $newImageName
    }
    $country = Get-NavContainerCountry -containerOrImageName $newImageName

    if (Test-Container -containerName navserver) {
        Write-Host "Remove container navserver"
        Remove-NavContainerSession -containerName $containerName
        $containerId = Get-ContainerId -containerName $containerName
        docker rm $containerId -f | Out-Null
    }
    
    $settingsScript = "c:\demo\settings.ps1"
    $settings = Get-Content -Path  $settingsScript
    0..($settings.Count-1) | % { if ($settings[$_].StartsWith('$navDockerImage = ')) { $settings[$_] = ('$navDockerImage = "'+$newImageName + '"') } }
    Set-Content -Path $settingsScript -Value $settings

    Write-Host -ForegroundColor Green "Setup new Nav container"
    . $SetupNavContainerScript
    . $setupDesktopScript
}

function Recreate-NavServerContainer {
    Param(
        [string]$certificatePfxUrl = "", 
        [string]$certificatePfxPassword = "", 
        [string]$publicDnsName = ""
    )

    $imageName = Get-NavContainerImageName -containerName navserver
    Replace-NavServerContainer -imageName $imageName -certificatePfxUrl $certificatePfxUrl -certificatePfxPassword $certificatePfxPassword -publicDnsName $publicDnsName
}
