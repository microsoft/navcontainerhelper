<# 
 .Synopsis
  Extract Files From stopped NAV/BC Container
 .Description
  Extract all files from a Container Image necessary to start a generic container with these files
 .Parameter containerName
  Name of the Container from which you want to extract the files
 .Parameter path
  Location where you want the files to be placed
 .Parameter extract
  Determine what you need to extract (default is all)
 .Parameter force
  Specify -force if you want to automatically stop the container if running and remove the destination folder if it exists
 .Example
  Extract-FilesFromStoppedBcContainer -ContainerName temp -Path "c:\programdata\bccontainerhelper\extensions\acontainer\afolder"
#>
function Extract-FilesFromStoppedBcContainer {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $path,
        [ValidateSet('all','vsix','database')]
        [string] $extract = "all",
        [switch] $force
    )

    $artifactUrl = Get-BcContainerArtifactUrl -containerName $imageName
    if ($artifactUrl) {
        throw "Extract-FilesFromStoppedBcContainer doesn't support containers based on artifacts."
        return
    }

    $startContainer = $false
    if ((docker inspect -f '{{.State.Running}}' $containerName) -eq "true") {
        if (!$force) {
            throw "Container is running. Cannot extract files from a running container"
        }
        $startContainer = $true
        Stop-BcContainer $containerName | Out-Null
    }

    if (Test-Path -Path $path) {
        if (!$force) { 
            throw "Destination folder '$path' already exists"
        }
        Remove-Item -Path "$path\*" -Recurse -Force
    }
    else {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }

    $ErrorActionPreference = 'Continue'

    if ($extract -eq "all") {

        $inspect = docker inspect $containerName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('platform').Count -ne 0) {
            Set-Content -Path "$path\platform.txt" -value "$($inspect.Config.Labels.platform)"
        }
        $country = $inspect.Config.Labels.Country
        Set-Content -Path "$path\country.txt" -value "$country"
        Set-Content -Path "$path\version.txt" -value "$($inspect.Config.Labels.Version)"

        New-Item "$path\ServiceTier\System64Folder" -ItemType Directory | Out-Null
        New-Item "$path\ServiceTier\Program Files" -ItemType Directory | Out-Null
        New-Item "$path\WebClient\Microsoft Dynamics NAV" -ItemType Directory | Out-Null
        New-Item "$path\RoleTailoredClient\systemFolder" -ItemType Directory | Out-Null
        New-Item "$path\RoleTailoredClient\Program Files" -ItemType Directory | Out-Null
        New-Item "$path\ClickOnceInstallerTools\Program Files\Microsoft Dynamics NAV" -ItemType Directory | Out-Null
        New-Item "$path\WindowsPowerShellScripts\Cloud" -ItemType Directory | Out-Null
        New-Item "$path\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV\VER" -ItemType Directory | Out-Null
        
        Write-Host "Extracting Service Tier and WebClient Files"
        docker cp "$($containerName):\Windows\System32\NavSip.dll" "$path\ServiceTier\System64Folder"
        docker cp "$($containerName):\Program Files\Microsoft Dynamics NAV" "$path\ServiceTier\program files\Microsoft Dynamics NAV"
        Write-Host "Extracting Windows Client Files"
        docker cp "$($containerName):\Windows\SysWow64\NavSip.dll" "$path\RoleTailoredClient\systemFolder" 2>$null
        docker cp "$($containerName):\Program Files (x86)\Microsoft Dynamics NAV" "$path\RoleTailoredClient\Program Files"
        Write-Host "Extracting Configuration packages"
        docker cp "$($containerName):\ConfigurationPackages" "$path" 2>$null
        Write-Host "Extracting Test Assemblies"
        docker cp "$($containerName):\Test Assemblies" "$path" 2>$null
        Write-Host "Extracting Test Toolkit"
        docker cp "$($containerName):\TestToolKit" "$path" 2>$null
        Write-Host "Extracting Upgrade Toolkit"
        docker cp "$($containerName):\UpgradeToolKit" "$path" 2>$null
        Write-Host "Extracting Extensions"
        docker cp "$($containerName):\Extensions" "$path" 2>$null
        Write-Host "Extracting Applications"
        docker cp "$($containerName):\Applications" "$path" 2>$null
        Write-Host "Extracting Applications.$country"
        docker cp "$($containerName):\Applications.$country" "$path" 2>$null

        $customConfigFile = (Get-Item "$path\ServiceTier\program files\Microsoft Dynamics NAV\*\Service\CustomSettings.config").FullName
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -eq "true") {
            Remove-Item -Path $path -Recurse -Force
            throw "Extract-Files cannot be performed on multitenant containers/images, use artifacts"
        }

        $sourceFolder = (Get-Item "$path\ServiceTier\Program Files\Microsoft Dynamics NAV\*\Web Client").FullName
        $destFolder = $sourceFolder.Replace('\Web Client','').Replace('ServiceTier\Program Files','WebClient')
        New-Item -Path $destFolder -ItemType Directory | Out-Null
        Move-Item -Path $sourceFolder -Destination $destFolder

        $sourceItem = Get-Item "$path\ServiceTier\Program Files\Microsoft Dynamics NAV\*\AL Development Environment"
        if ($sourceItem) {
            $sourceFolder = $SourceItem.FullName
            $destFolder = $sourceFolder.Replace('\AL Development Environment','').Replace('ServiceTier\','ModernDev\')
            New-Item -Path $destFolder -ItemType Directory | Out-Null
            Move-Item -Path $sourceFolder -Destination $destFolder
        }
        
        $sourceItem = Get-Item "$path\RoleTailoredClient\Program Files\Microsoft Dynamics NAV\*\ClickOnce Installer Tools"
        if ($sourceItem) {
            $sourceFolder = $SourceItem.FullName
            $destFolder = $sourceFolder.Replace('\ClickOnce Installer Tools','').Replace('\RoleTailoredClient\','\ClickOnceInstallerTools\')
            New-Item -Path $destFolder -ItemType Directory | Out-Null
            Move-Item -Path $sourceFolder -Destination $destFolder
        }
    }
    if ($extract -eq "all" -or $extract -eq "vsix") {
        Write-Host "Extracting Files from Run folder"
        docker cp "$($containerName):\Run" "$path"
    }
    if ($extract -eq "all" -or $extract -eq "database") {
        Write-Host "Extracting Database Files"
        docker cp "$($containerName):\databases" "$path" 2>$null
    }

    if ($extract -eq "all") {
        Write-Host "Downloading prerequisites"
        $ver = [int]((get-childitem "$path\ServiceTier\Program Files\Microsoft Dynamics NAV").Name)
        Download-File -dontOverwrite -sourceUrl "https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi" -destinationFile "$path\Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi"
        Download-File -dontOverwrite -sourceUrl "https://download.microsoft.com/download/5/5/3/553C731E-9333-40FB-ADE3-E02DC9643B31/OpenXMLSDKV25.msi" -destinationFile "$path\Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi" 
        if ($ver -eq 90) {
            Download-File -dontOverwrite -sourceUrl "https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x86/SQLSysClrTypes.msi" -destinationFile "$path\Prerequisite Components\Microsoft Report Viewer 2015\SQLSysClrTypes.msi"
            Download-File -dontOverwrite -sourceUrl "https://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi" -destinationFile "$path\Prerequisite Components\Microsoft Report Viewer 2015\ReportViewer.msi"
        } elseif ($ver -eq 100) {
            Download-File -dontOverwrite -sourceUrl "https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x86/SQLSysClrTypes.msi" -destinationFile "$path\Prerequisite Components\Microsoft Report Viewer\SQLSysClrTypes.msi"
            Download-File -dontOverwrite -sourceUrl "https://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi" -destinationFile "$path\Prerequisite Components\Microsoft Report Viewer\ReportViewer.msi" 
        } elseif ($ver -ge 110) {
            Download-File -dontOverwrite -sourceUrl "https://go.microsoft.com/fwlink/?LinkID=844461" -destinationFile "$path\Prerequisite Components\DotNetCore\DotNetCore.1.0.4_1.1.1-WindowsHosting.exe"
        }
    }

    Write-Host "Performing cleanup"
    if ($extract -eq "all" -or $extract -eq "database") {
        if (Test-Path "$path\databases\*.mdf") {
            
            Move-Item -Path (Get-Item "$path\databases\*.mdf").FullName -Destination "$path\databases\CRONUS.mdf"
            Move-Item -Path (Get-Item "$path\databases\*.ldf").FullName -Destination "$path\databases\CRONUS.ldf"
        } else {
            $folder = Get-ChildItem -Path "$path\databases" -Directory
            if ($folder) {
                $name = $folder.Name
                Move-Item -Path (Get-Item "$path\databases\$Name\*.mdf").FullName -Destination "$path\databases\$name.mdf"
                Move-Item -Path (Get-Item "$path\databases\$Name\*.ldf").FullName -Destination "$path\databases\$name.ldf"
                Remove-Item $folder.FullName -Recurse -Force
            } else {
                docker cp "$($containerName):\Program Files\Microsoft SQL Server\MSSQL13.SQLEXPRESS\MSSQL\DATA" "$path" 2>$null
                docker cp "$($containerName):\Program Files\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQL\DATA" "$path" 2>$null
                docker cp "$($containerName):\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\DATA" "$path" 2>$null
                $mdffile = Get-Item "$path\DATA\Financials*.mdf"
                if ($mdffile) {
                    $name = $mdffile.Name.SubString(0,$mdffile.Name.IndexOf('_'))
                    Move-Item -Path (Get-Item "$path\DATA\Financials*.mdf").FullName -Destination "$path\databases\$name.mdf"
                    Move-Item -Path (Get-Item "$path\DATA\Financials*.ldf").FullName -Destination "$path\databases\$name.ldf"
                    Remove-Item -path "$path\DATA" -Recurse -Force
                } else {
                    throw "Cannot locate database"
                }
            }
        }
        if (Test-Path "$path\Run\Collation.txt") {
            Move-Item -Path "$path\Run\Collation.txt" -Destination "$path\databases\Collation.txt"
        }
    }
    
    if ($extract -eq "all") {
        Copy-Item -Path "$path\Run\NAVAdministration" -Destination "$path\WindowsPowerShellScripts\Cloud" -Force -Recurse
        if (Test-Path "$path\Run\WebSearch") {
            Copy-Item -Path "$path\Run\WebSearch" -Destination "$path\WindowsPowerShellScripts\Cloud" -Force -Recurse
        }

        if ($ver -lt 150) {
            Copy-Item -Path "$path\Run\ClientUserSettings.config" -Destination "$path\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV\VER" -Force
        }
        If (Test-Path "$path\Run\inetpub") {
            Copy-Item -Path "$path\Run\inetpub" -Destination "$path\WebClient" -Force -Recurse
        }
    }
    if ($extract -eq "all" -or $extract -eq "vsix") {
        Copy-Item -Path "$path\Run\*.vsix" -Destination "$path" -Force
        Remove-Item -Path "$path\Run" -Recurse -Force
    }
    
    if ($extract -eq "all") {
        New-Item -Path "$path\allextracted" -ItemType File | Out-Null
    }

    $ErrorActionPreference = 'Stop'

    if ($startContainer) {
        Start-BcContainer -containerName $containerName
    }
}
Set-Alias -Name Extract-FilesFromStoppedNavContainer -Value Extract-FilesFromStoppedBcContainer
Export-ModuleMember -Function Extract-FilesFromStoppedBcContainer -Alias Extract-FilesFromStoppedNavContainer
