Set-StrictMode -Version 2.0

$verbosePreference = "SilentlyContinue"
$warningPreference = "SilentlyContinue"
$errorActionPreference = 'Stop'

$demoFolder = "C:\DEMO"
New-Item -Path $demoFolder -ItemType Container -Force -ErrorAction Ignore
$extensionsFolder = Join-Path $demoFolder "Extensions"
New-Item -Path $extensionsFolder -ItemType Container -Force -ErrorAction Ignore

$containerDemoFolder = "C:\DEMO"

$sessions = @{}

#region Internal helper functions

function Log([string]$line, [string]$color = "Gray") { 
    Write-Host -ForegroundColor $color $line
}

function Get-DefaultAdminPassword {
    if (!(Test-Path "$demoFolder\settings.ps1")) {
        throw "You need to specify adminPassword"
    }
    . "$demoFolder\settings.ps1"
    return $adminPassword
}

function Get-DefaultVmAdminUsername {
    if (Test-Path "$demoFolder\settings.ps1") {
        . "$demoFolder\settings.ps1"
        return $vmAdminUsername
    } elseif ("$env:USERNAME" -ne "") {        
        return "$env:USERNAME"
    } else {
        return "vmadmin"
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

function Get-LocaleFromCountry {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$country
    )

    $locales = @{
        "finus" = "en-US"
        "finca" = "en-CA"
        "fingb" = "en-GB"
        "findk" = "da-DK"
        "at"    = "de-AT"
        "au"    = "en-AU" 
        "be"    = "nl-BE"
        "ch"    = "de-CH"
        "cz"    = "cs-CZ"
        "de"    = "de-DE"
        "dk"    = "da-DK"
        "es"    = "es-ES"
        "fi"    = "fi-FI"
        "fr"    = "fr-FR"
        "gb"    = "en-GB"
        "in"    = "en-IN"
        "is"    = "is-IS"
        "it"    = "it-IT"
        "na"    = "en-US"
        "nl"    = "nl-NL"
        "no"    = "nb-NO"
        "nz"    = "en-NZ"
        "ru"    = "ru-RU"
        "se"    = "sv-SE"
        "w1"    = "en-US"
        "us"    = "en-US"
        "mx"    = "es-MX"
        "ca"    = "en-CA"
        "dech"  = "de-CH"
        "frbe"  = "fr-BE"
        "frca"  = "fr-CA"
        "frch"  = "fr-CH"
        "itch"  = "it-CH"
        "nlbe"  = "nl-BE"
    }

    return $locales[$country]
}

function Copy-FileFromNavContainer {

    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$containerPath,
        [Parameter(Mandatory=$false)]
        [string]$localPath = $containerPath
    )

    Process {
        if (!(Test-NavContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy from container $containerName ($containerPath) to $localPath"
        $id = Get-NavContainerId -containerName $containerName 
        docker cp ${id}:$containerPath $localPath
    }
}

function Copy-FileToNavContainer {

    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$localPath,
        [Parameter(Mandatory=$false)]
        [string]$containerPath = $localPath
    )

    Process {
        if (!(Test-NavContainer -containerName $containerName)) {
            throw "Container $containerName does not exist"
        }
        Log "Copy $localPath to container ${containerName} ($containerPath)"
        $id = Get-NavContainerId -containerName $containerName 
        docker cp $localPath ${id}:$containerPath
    }
}

function Update-Hosts {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$hostName,
        [string]$ip
    ) 

    $hostsFile = "c:\windows\system32\drivers\etc\hosts"

    if (Test-Path $hostsFile) {
        $retry = $true
        while ($retry) {
            try {
                [System.Collections.ArrayList]$hosts = @(Get-Content -Path $hostsFile -Encoding Ascii)
                $retry = $false
            } catch {
                Start-Sleep -Seconds 1
            }
        }
    } else {
        $hosts = New-Object System.Collections.ArrayList
    }
    $ln = 0
    while ($ln -lt $hosts.Count) {
        $line = $hosts[$ln]
        $idx = $line.IndexOf('#')
        if ($idx -ge 0) {
            $line = $line.Substring(0,$idx)
        }
        $hidx = ("$line ".Replace("`t"," ")).IndexOf(" $hostName ")
        if ($hidx -ge 0) {
            $hosts.RemoveAt($ln) | Out-Null
        } else {
            $ln++
        }
    }
    if ("$ip" -ne "") {
        $hosts.Add("$ip $hostName") | Out-Null
    }
    $retry = $true
    while ($retry) {
        try {
            Set-Content -Path $hostsFile -Value $($hosts -join [Environment]::NewLine) -Encoding Ascii -Force -ErrorAction Ignore
            $retry = $false
        } catch {
            Start-Sleep -Seconds 1
        }
    }
}

#endregion Internal helper functions

<# 
 .Synopsis
  Get (or create) a PSSession for a Nav Container
 .Description
  Checks the session cache for an existing session. If a session exists, it will be reused.
  If no session exists, a new session will be created.
 .Parameter containerName
  Name of the container for which you want to create a session
 .Example
  $session = Get-NavContainerSession -containerName navserver
  PS C:\>Invoke-Command -Session $session -ScriptBlock { Set-NavServerInstance -ServerInstance NAV -restart }
#>
function Get-NavContainerSession {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $containerId = Get-NavContainerId -containerName $containerName

        if (!($sessions.ContainsKey($containerId))) {
            $session = New-PSSession -ContainerId $containerId -RunAsAdministrator
            Invoke-Command -Session $session -ScriptBlock {
                . "c:\run\prompt.ps1" | Out-Null
                . "c:\run\HelperFunctions.ps1" | Out-Null

                $txt2al = $NavIde.replace("finsql.exe","txt2al.exe")
                cd c:\run
            }
            $sessions.Add($containerId, $session)
        }
        $sessions[$containerId]
    }
}
Export-ModuleMember -function Get-NavContainerSession

<# 
 .Synopsis
  Remove a PSSession for a Nav Container
 .Description
  If a session exists in the session cache, it will be removed and disposed.
  Remove-CsideDevContainer automatically removes sessions created.
 .Parameter containerName
  Name of the container for which you want to remove the session
 .Example
  Remove-NavContainerSession -containerName navserver
#>
function Remove-NavContainerSession {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $containerId = Get-NavContainerId -containerName $containerName

        if ($sessions.ContainsKey($containerId)) {
            $session = $sessions[$containerId]
            Remove-PSSession -Session $session
            $sessions.Remove($containerId)
        }
    }
}
Export-ModuleMember -function Remove-NavContainerSession

<# 
 .Synopsis
  Enter PowerShell session in Nav Container
 .Description
  Use the current PowerShell prompt to enter a PowerShell session in a Nav Container.
  Especially useful in PowerShell ISE, where you after entering a session, can use PSEdit to edit files inside the container.
  The PowerShell session will have the Nav PowerShell modules pre-loaded, meaning that you can use most Nav PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Example
  Enter-NavContainer -containerName
  [64b6ca872aefc93529bdfc7ec0a4eb7a2f0c022942000c63586a48c27b4e7b2d]: PS C:\run>psedit c:\run\navstart.ps1
#>
function Enter-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $session = Get-NavContainerSession $containerName
        Enter-PSSession -Session $session
    }
}
Export-ModuleMember -function Enter-NavContainer

<# 
 .Synopsis
  Open a new PowerShell session for a Nav Container
 .Description
  Opens a new PowerShell window for a Nav Container.
  The PowerShell prompt will have the Nav PowerShell modules pre-loaded, meaning that you can use most Nav PowerShell CmdLets.
 .Parameter containerName
  Name of the container for which you want to open a session
 .Example
  Open-NavContainer -containerName navserver
#>
function Open-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        Start-Process "cmd.exe" @("/C";"docker exec -it $containerName powershell -noexit C:\Run\prompt.ps1")
    }
}
Export-ModuleMember -function Open-NavContainer

<# 
 .Synopsis
  Get the version of NAV in a Nav container or a Nav container image
 .Description
  Returns the version of NAV in the format major.minor.build.release
 .Parameter containerOrImageName
  Name of the container or container image for which you want to enter a session
 .Example
  Get-NavContainerNavVersion -containerOrImageName navserver
 .Example
  Get-NavContainerNavVersion -containerOrImageName navdocker.azurecr.io/dynamics-nav:2017
#>
function Get-NavContainerNavVersion {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        return "$($inspect.Config.Labels.version)-$($inspect.Config.Labels.country)"
    }
}
Export-ModuleMember -function Get-NavContainerNavVersion

<# 
 .Synopsis
  Get the name of the image used to run a Nav container
 .Description
  Get the name of the image used to run a Nav container
  The image name can be used to run a new instance of a Nav Container with the same version of Nav
 .Parameter containerName
  Name of the container for which you want to get the image name
 .Example
  $imageName = Get-NavContainerImageName -containerName navserver
  PS C:\>Docker run -e accept_eula=Y $imageName
#>
function Get-NavContainerImageName {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        return "$($inspect.Config.Image)"
    }
}
Export-ModuleMember -function Get-NavContainerImageName

<# 
 .Synopsis
  Get the generic tag for a Nav container or a Nav container image
 .Description
  Returns the generic Tag version referring to a release from http://www.github.com/microsoft/nav-docker
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the generic tag
 .Example
  Get-NavContainerGenericTag -containerOrImageName navserver
 .Example
  Get-NavContainerGenericTag -containerOrImageName navdocker.azurecr.io/dynamics-nav:2017
#>
function Get-NavContainerGenericTag {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        return "$($inspect.Config.Labels.tag)"
    }
}
Export-ModuleMember -function Get-NavContainerGenericTag

<# 
 .Synopsis
  Get the OS Version for a Nav container or a Nav container image
 .Description
  Returns the version of the WindowsServerCore image used to build the Nav container or Nav containerImage
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the OS Version
 .Example
  Get-NavContainerOsVersion -containerOrImageName navserver
 .Example
  Get-NavContainerOsVersion -containerOrImageName navdocker.azurecr.io/dynamics-nav:2017
#>
function Get-NavContainerOsVersion {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        # returns empty with generic tag 0.0.2.3 or earlier
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        return "$($inspect.Config.Labels.osversion)"
    }
}
Export-ModuleMember -function Get-NavContainerOsVersion

<# 
 .Synopsis
  Get the Legal Link for for a Nav container or a Nav container image
 .Description
  Returns the Legal link for the version of Nav in the Nav container or Nav containerImage
  This is the Eula, which you accept when running the Nav Container using -e accept_eula=Y
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the legal link
 .Example
  Get-NavContainerLegal -containerOrImageName navserver
 .Example
  Get-NavContainerLegal -containerOrImageName navdocker.azurecr.io/dynamics-nav:2017
#>
function Get-NavContainerLegal {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        return "$($inspect.Config.Labels.legal)"
    }
}
Export-ModuleMember -function Get-NavContainerLegal

<# 
 .Synopsis
  Get the country version of Nav for a Nav container or a Nav container image
 .Description
  Returns the country version (localization) for the version of Nav in the Nav container or Nav containerImage
  Financials versions of Nav will be preceeded by 'fin', like finus, finca, fingb.
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the country version
 .Example
  Get-NavContainerCountry -containerOrImageName navserver
 .Example
  Get-NavContainerCountry -containerOrImageName navdocker.azurecr.io/dynamics-nav:2017
#>
function Get-NavContainerCountry {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerOrImageName
    )

    Process {
        $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
        return "$($inspect.Config.Labels.country)"
    }
}
Export-ModuleMember -function Get-NavContainerCountry
<# 
 .Synopsis
  Get the IP Address of a Nav container
 .Description
  Inspect the Nav Container and return the IP Address of the first network.
 .Parameter containerName
  Name of the container for which you want to get the IP Address
 .Example
  Get-NavContainerIpAddress -containerName navserver
#>
function Get-NavContainerIpAddress {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        $networks = $inspect.NetworkSettings.Networks
        $network = ($networks | get-member -MemberType NoteProperty | select Name).Name
        return ($networks | Select-Object -ExpandProperty $network).IPAddress
    }
}
Export-ModuleMember -function Get-NavContainerIpAddress

<# 
 .Synopsis
  Get a list of folders shared with a Nav container
 .Description
  Returns a hastable of folders shared with the container.
  The name in the hashtable is the local folder, the value is the folder inside the container
 .Parameter containerName
  Name of the container for which you want to get the shared folder list
 .Example
  Get-NavContainerSharedFolders -containerName navserver
 .Example
  (Get-NavContainerSharedFolders -containerName navserver)["c:\demo"]
 .Example
  ((Get-NavContainerSharedFolders -containerName navserver).GetEnumerator() | Where-Object { $_.Value -eq "c:\run\my" }).Key
#>
function Get-NavContainerSharedFolders {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        $sharedFolders = @{}
        if ($inspect.HostConfig.Binds) {
            $inspect.HostConfig.Binds | % {
                $idx = $_.IndexOf(':', $_.IndexOf(':') + 1)
                $sharedFolders += @{$_.Substring(0, $idx) = $_.SubString($idx+1) }
            }
        }
        return $sharedFolders
    }
}
Export-ModuleMember -function Get-NavContainerSharedFolders

<# 
 .Synopsis
  Get the container file system path of a host file
 .Description
  Enumerates the shared folders with the container and returns the container file system path for a file shared with the container.
 .Parameter containerName
  Name of the container for which you want to find the filepath
 .Parameter path
  Path of a file in the host file system
 .Example
  $containerPath = Get-NavContainerPath -containerName navserver -path c:\demo\extensions\test2\my
#>
function Get-NavContainerPath {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$path,
        [switch]$throw
    )

    Process {
        $containerPath = ""
        $sharedFolders = Get-NavContainerSharedFolders -containerName $containerName
        $sharedFolders.GetEnumerator() | % {
            if ($containerPath -eq "" -and ($path -eq $_.Name -or $path.StartsWith($_.Name+"\", "OrdinalIgnoreCase"))) {
                $containerPath = ($_.Value + $path.Substring($_.Name.Length))
            }
        }
        if ($throw -and "$containerPath" -eq "") {
            throw "The folder $path is not shared with the container $containerName (nor is any of it's parent folders)"
        }
        return $containerPath
    }
}
Export-ModuleMember -function Get-NavContainerPath

<# 
 .Synopsis
  Get the name of a Nav container
 .Description
  Returns the name of a Nav container based on the container Id
  You need to specify enought characters of the Id to make it unambiguous
 .Parameter containerId
  Id (or part of the Id) of the container for which you want to get the name
 .Example
  Get-NavContainerName -containerId 7d
#>
function Get-NavContainerName {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerId
    )

    docker ps --format='{{.Names}}' -a --filter "id=$containerId"
}
Export-ModuleMember -function Get-NavContainerName

<# 
 .Synopsis
  Test whether a Nav container exists
 .Description
  Returns $true if the Nav container with the specified name exists
 .Parameter containerName
  Name of the container which you want to check for existence
 .Example
  if (Test-NavContainer -containerName devcontainer) { dosomething }
#>
function Test-NavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    Process {
        $exist = $false
        docker ps --filter name="$containerName" -a -q --no-trunc | % {
            $name = Get-NavContainerName -containerId $_
            if ($name -eq $containerName) {
                $exist = $true
            }
        }
        $exist
    }
}
Export-ModuleMember -function Test-NavContainer

<# 
 .Synopsis
  Get the Id of a Nav container
 .Description
  Returns the Id of a Nav container based on the container name
  The Id returned is the full 64 digit container Id and the name must match
 .Parameter containerName
  Name of the container for which you want the Id
 .Example
  Get-NavContainerId -containerId navserver
#>
function Get-NavContainerId {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $id = ""
        docker ps --filter name="$containerName" -a -q --no-trunc | % {
            # filter only filters on the start of the name
            $name = Get-NavContainerName -containerId $_
            if ($name -eq $containerName) {
                $id = $_
            }
        }
        $id
    }
}
Export-ModuleMember -function Get-NavContainerId

<# 
 .Synopsis
  Create or refresh a CSide Development container
 .Description
  Creates a new container based on a Nav Docker Image
  Adds shortcut on the desktop for CSIDE, Windows Client, Web Client and Container PowerShell prompt.
  The command also exports all objects to a baseline folder to be used for delta creation
 .Parameter containerName
  Name of the new CSide Development container (if the container already exists it will be replaced)
 .Parameter devImageName
  Name of the image you want to use for your CSide Development container (default is to grab the imagename from the navserver container)
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use (default c:\demo\license.flf)
 .Parameter vmAdminUsername
  Name of the administrator user you want to add to the container
 .Parameter adminPassword
  Password of the administrator user you want to add to the container
 .Parameter memoryLimit
  Memory limit for the container (default 4G)
 .Parameter updateHosts
  Include this switch if you want to update the hosts file with the IP address of the container
 .Example
  New-SideDevContainer -containerName test
 .Example
  New-SideDevContainer -containerName test -memoryLimit 3G -devImageName "navdocker.azurecr.io/dynamics-nav:2017" -updateHosts
 .Example
  New-CSideDevContainer -containerName test -adminPassword <mypassword> -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1" -devImageName "navdocker.azurecr.io/dynamics-nav:devpreview-finus"
#>
function New-CSideDevContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$devImageName = "", 
        [string]$licenseFile = "",
        [string]$vmAdminUsername = (Get-DefaultVmAdminUsername), 
        [string]$adminPassword = (Get-DefaultAdminPassword),
        [string]$memoryLimit = "4G",
        [switch]$UpdateHosts
    )

    if ($containerName -eq "navserver") {
        throw "You cannot create a CSide development container called navserver. Use Replace-NavServerContainer to replace the navserver container."
    }
  
    if ($licenseFile -eq "") {
        $licenseFile = "C:\DEMO\license.flf"
        if (!(Test-Path -Path $licenseFile)) {
            throw "You must specify a license file to use for the CSide Development container."
        }
    } elseif ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
    } elseif (!(Test-Path $licenseFile)) {
        throw "License file '$licenseFile' must exist in order to create a Developer Server Container."
    }

    if ($devImageName -eq "") {
        if (!(Test-NavContainer -containerName navserver)) {
            throw "You need to specify the name of the docker image you want to use for your development container."
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

    Write-Host "Creating C/SIDE developer container $containerName"
    Write-Host "Using image $devImageName"
    Write-Host "Using license file $licenseFile"
    $navversion = Get-NavContainerNavversion -containerOrImageName $devImageName
    Write-Host "NAV Version: $navversion"
    $locale = Get-LocaleFromCountry $devCountry

    if (Test-NavContainer -containerName $containerName) {
        Remove-CSideDevContainer $containerName -UpdateHosts:$UpdateHosts
    }

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $programFilesFolder = Join-Path $containerFolder "Program Files"
    New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    if ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
        $containerLicenseFile = $licenseFile
    } else {
        Copy-Item -Path $licenseFile -Destination "$myFolder\license.flf" -Force
        $containerLicenseFile = "c:\run\my\license.flf"
    }

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

    if ($UpdateHosts) {
        $ip = Get-NavContainerIpAddress -containerName $containerName
        Write-Host "Add $ip $containerName to hosts"
        Update-Hosts -hostName $containerName -ip $ip
    }

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

    $suffix = "-newsyntax"
    $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"
    if (!(Test-Path $originalFolder)) {
        # Export base objects
        Export-NavContainerObjects -containerName $containerName `
                                   -objectsFolder $originalFolder `
                                   -filter "" `
                                   -adminPassword $adminPassword `
                                   -ExportToNewSyntax $true
    }

    Write-Host -ForegroundColor Green "C/SIDE developer container $containerName successfully created"
}
Export-ModuleMember -function New-CSideDevContainer

<# 
 .Synopsis
  Remove CSide Development container
 .Description
  Remove container, Session, Shortcuts, temp. files and entries in the hosts file,
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter updateHosts
  Include this switch if you want to update the hosts file and remove the container entry
 .Example
  Remove-CSideDevContainer -containerName devServer
 .Example
  Remove-CSideDevContainer -containerName test -updateHosts
#>
function Remove-CSideDevContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [switch]$UpdateHosts
    )

    Process {
        if ($containerName -eq "navserver") {
            throw "You should not remove the navserver container. Use Replace-NavServerContainer to replace the navserver container."
        }

        if (Test-NavContainer -containerName $containerName) {
            Remove-NavContainerSession $containerName
            $containerId = Get-NavContainerId -containerName $containerName
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
            if ($UpdateHosts) {
                Write-Host "Remove $containerName from hosts"
                Update-Hosts -hostName $containerName -ip ""
            }
            Write-Host -ForegroundColor Green "Successfully removed container $containerName"
        }
    }
}
Export-ModuleMember -function Remove-CSideDevContainer

<# 
 .Synopsis
  Wait for Nav container to become ready
 .Description
  Wait for Nav container to log "Ready for connections!"
  If the container experiences an error, the function will throw an exception
 .Parameter containerName
  Name of the container for which you want to wait
 .Example
  Wait-NavContainerReady -containerName navserver
#>
function Wait-NavContainerReady {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        Write-Host "Waiting for container $containerName to be ready, this shouldn't take more than a few minutes"
        Write-Host "Time:          ½              1              ½              2"
        $cnt = 150
        $log = ""
        do {
            Write-Host -NoNewline "."
            Start-Sleep -Seconds 2
            $logs = docker logs $containerName
            if ($logs) { $log = [string]::Join("`r`n",$logs) }
            if ($cnt-- -eq 0 -or $log.Contains("<ScriptBlock>")) { 
                Write-Host "Error"
                Write-Host $log
                throw "Initialization of container $containerName failed"
            }
        } while (!($log.Contains("Ready for connections!")))
        Write-Host "Ready"
    }
}
Export-ModuleMember -function Wait-NavContainerReady

<# 
 .Synopsis
  Export objects from a Nav container
 .Description
  Creates a session to the Nav container and launch the Export-NavApplicationObjects Cmdlet to export object
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter objectsFolder
  The folder to which the objects are exported (needs to be shared with the container)
 .Parameter adminPassword
  The admin password for the container
 .Parameter filter
  Specifies which objects to export (default is modified=Yes)
 .Parameter exportToNewSyntax
  Specifies whether or not to export objects in new syntax (default is true)
 .Example
  Export-NavContainerObject -containerName test -objectsFolder c:\demo\objects
 .Example
  Export-NavContainerObject -containerName test -objectsFolder c:\demo\objects -adminPassword <password> -filter ""
#>
function Export-NavContainerObjects {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$objectsFolder, 
        [string]$adminPassword = (Get-DefaultAdminPassword), 
        [string]$filter = "modified=Yes", 
        [bool]$exportToNewSyntax = $true
    )

    $containerObjectsFolder = Get-NavContainerPath -containerName $containerName -path $objectsFolder -throw

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($filter, $objectsFolder, $adminPassword, $exportToNewSyntax)

        $objectsFile = "$objectsFolder.txt"
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
        Remove-Item -Path $objectsFolder -Force -Recurse -ErrorAction Ignore
        $filterStr = ""
        if ($filter) {
            $filterStr = " with filter '$filter'"
        }
        if ($exportToNewSyntax) {
            Write-Host "Export Objects$filterStr (new syntax) to $objectsFile"
        } else {
            Write-Host "Export Objects$filterStr to $objectsFile"
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
    
    }  -ArgumentList $filter, $containerObjectsFolder, $adminPassword, $exportToNewSyntax
}
Export-ModuleMember -function Export-NavContainerObjects

<# 
 .Synopsis
  Creates a folder with modified base objects
 .Description
  Compares files from the modifiedFolder with files in the originalFolder to identify which base objects have been changed.
  All changed base objects are copied to the myoriginalFolder, which allows the Create-MyDeltaFolder to identify new and modified objects.
 .Parameter $originalFolder, 
  Folder containig the original base objects
 .Parameter $modifiedFolder, 
  Folder containing your modified objects
 .Parameter $myoriginalFolder
  Folder in which the original objects for your modified objects are copied to
 .Example
  Create-MyOriginalFolder -originalFolder c:\demo\baseobjects -modifiedFolder c:\demo\myobjects -myoriginalFolder c:\demo\mybaseobjects
#>
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
Export-ModuleMember -function Create-MyOriginalFolder

<# 
 .Synopsis
  Create folder with delta files for my objects
 .Description
  Compare my objects with my base objects and create a folder with delta files.
  Modified objects will be stored as .delta files, new objects will be .txt files.
 .Parameter containerName
  Name of the container in which the Nav Development Cmdlets are to be executed
 .Parameter modifiedFolder
  Folder containing your modified objects
 .Parameter $myoriginalFolder
  Folder containing the original objects for your modified objects
 .Parameter myDeltaFolder
  Folder in which the delta files are created
 .Example
  Create-MyDeltaFolder -containerName test -modifiedFolder c:\demo\myobjects -myoriginalFolder c:\demo\myoriginalobjects -mydeltaFolder c:\demo\mydeltafiles
#>
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

    $containerModifiedFolder = Get-NavContainerPath -containerName $containerName -path $modifiedFolder -throw
    $containerMyOriginalFolder = Get-NavContainerPath -containerName $containerName -path $myOriginalFolder -throw
    $containerMyDeltaFolder = Get-NavContainerPath -containerName $containerName -path $myDeltaFolder -throw

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
    } -ArgumentList $containerModifiedFolder, $containerMyOriginalFolder, $containerMyDeltaFolder
}
Export-ModuleMember -function Create-MyDeltaFolder

<# 
 .Synopsis
  Convert txt and delta files to AL
 .Description
  Convert objects in myDeltaFolder to AL. Page and Table extensions are created as new objects using the startId as object Id offset.
  Code modifications and other things not supported in extensions will not be converted to AL.
  Manual modifications are required after the conversion.
 .Parameter containerName
  Name of the container in which the txt2al tool will be executed
 .Parameter myDeltaFolder
  Folder containing delta files
 .Parameter myAlFolder
  Folder in which the AL files are created
 .Parameter startId
  Starting offset for objects created by the tool (table and page extensions)
 .Example
  Convert-Txt2Al -containerName test -mydeltaFolder c:\demo\mydeltafiles -myAlFolder c:\demo\myAlFiles -startId 50100
#>
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

    $containerMyDeltaFolder = Get-NavContainerPath -containerName $containerName -path $myDeltaFolder -throw
    $containerMyAlFolder = Get-NavContainerPath -containerName $containerName -path $myAlFolder -throw

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($myDeltaFolder, $myAlFolder, $startId)

        if (!($txt2al)) {
            throw "You cannot run Convert-Txt2Al on this Nav Container"
        }
        Write-Host "Converting files in $myDeltaFolder to .al files in $myAlFolder with startId $startId"
        Remove-Item -Path $myAlFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myAlFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        Start-Process -FilePath $txt2al -ArgumentList "--source=""$myDeltaFolder"" --target=""$myAlFolder"" --rename --extensionStartId=$startId" -Wait -NoNewWindow
    
    } -ArgumentList $containerMyDeltaFolder, $containerMyAlFolder, $startId
}
Export-ModuleMember -function Convert-Txt2Al

<# 
 .Synopsis
  Convert modified objects in a Nav container to AL
 .Description
  This command will invoke the 4 commands in order to export modified objects and convert them to AL:
  1. Export-NavContainerObjects
  2. Create-MyOriginalFolder
  3. Create-MyDeltaFolder
  4. Convert-Txt2Al
  A folder with the name of the container is created underneath c:\demo\extensions for holding all the temp and the final output.
  The command will open a windows explorer window with the output
 .Parameter containerName
  Name of the container for which you want to export and convert objects
 .Parameter adminPassword
  The admin password for the container
 .Parameter startId
  Starting offset for objects created by the tool (table and page extensions)
 .Example
  Convert-ModifiedObjectsToAl -containerName test
 .Example
  Convert-ModifiedObjectsToAl -containerName test -adminPassword <adminPassword> -startId 881200
#>
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
        throw "You cannot run Convert-ModifiedObjectsToAl on this Nav Container, the txt2al tool is not present."
    }

    if ((Get-NavContainerSharedFolders -containerName $containerName)[$demoFolder] -ne $containerDemoFolder) {
        throw "In order to run Convert-ModifiedObjectsToAl you need to have shared $demoFolder to $containerDemoFolder in the container (docker run ... -v ${demoFolder}:$containerDemoFolder ... <image>)."
    }

    $suffix = "-newsyntax"
    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"

    if (!(Test-Path $originalFolder)) {
        throw "Folder $originalFolder must contain all Nav base objects (original). You can use Export-NavContainerObjects on a fresh container or create your development container using New-CSideDevContainer, which does this automatically."
    }

    $modifiedFolder   = Join-Path $ExtensionsFolder "$containerName\modified$suffix"
    $myOriginalFolder = Join-Path $ExtensionsFolder "$containerName\original$suffix"
    $myDeltaFolder    = Join-Path $ExtensionsFolder "$containerName\delta$suffix"
    $myAlFolder       = Join-Path $ExtensionsFolder "$containerName\al$suffix"

    # Export my objects
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
Export-ModuleMember -Function Convert-ModifiedObjectsToAl

<# 
 .Synopsis
  Import Objects to Nav Container
 .Description
  Copy the object file to the Nav container if necessary.
  Create a session to a Nav container and run Import-NavApplicationObject
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter objectsFile
  Path of the objects file you want to import
 .Example
  Import-ObjectsToNavContainer -containerName test2 -objectsFile c:\temp\objects.txt -adminPassword <adminpassword>
#>
function Import-ObjectsToNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$objectsFile,
        [string]$adminPassword = (Get-DefaultAdminPassword)
    )

    $containerObjectsFile = Get-NavContainerPath -containerName $containerName -path $objectsFile
    $copied = $false
    if ("$containerObjectsFile" -eq "") {
        $containerObjectsFile = Join-Path "c:\run" ([System.IO.Path]::GetFileName($objectsFile))
        Copy-FileToNavContainer -containerName $containerName -localPath $objectsFile -containerPath $containerObjectsFile
        $copied = $true
    }

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($objectsFile, $adminPassword, $copied)
    
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

        if ($copied) {
            Remove-Item -Path $objectsFile -Force
        }
    
    } -ArgumentList $containerObjectsFile, $adminPassword, $copied
    Write-Host -ForegroundColor Green "Objects successfully imported"
}
Export-ModuleMember -Function Import-ObjectsToNavContainer

<# 
 .Synopsis
  Compile Objects to Nav Container
 .Description
  Create a session to a Nav container and run Compile-NavApplicationObject
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter filter
  filter of the objects you want to compile (default is modified=Yes)
 .Parameter adminPassword
  Password of the administrator user in the container
 .Example
  Compile-ObjectsToNavContainer -containerName test2 -adminPassword <adminpassword>
#>
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
Export-ModuleMember -Function Compile-ObjectsInNavContainer

<# 
 .Synopsis
  Publish Nav App to a Nav container
 .Description
  Copies the appFile to the container if necessary
  Creates a session to the Nav container and runs the Nav CmdLet Publish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to publish an app (default is navserver)
 .Parameter appFile
  Path of the app you want to publish  
 .Parameter skipVerification
  Include this parameter if the app you want to publish is not signed
 .Example
  Publish-NavContainerApp -appFile c:\temp\myapp.app
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification
#>
function Publish-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appFile,
        [switch]$skipVerification
    )

    $containerAppFile = Get-NavContainerPath -containerName $containerName -path $appFile
    $copied = $false
    if ("$containerAppFile" -eq "") {
        $containerAppFile = Join-Path "c:\run" ([System.IO.Path]::GetFileName($appFile))
        Copy-FileToNavContainer -containerName $containerName -localPath $appFile -containerPath $containerAppFile
        $copied = $true
    }
    
    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appFile, $skipVerification, $copied)
        Write-Host "Publishing app $appFile"
        Publish-NavApp -ServerInstance NAV -Path $appFile -SkipVerification:$SkipVerification
        if ($copied) { 
            Remove-Item $appFile -Force
        }
    } -ArgumentList $containerAppFile, $skipVerification, $copied
    Write-Host -ForegroundColor Green "App successfully published"
}
Export-ModuleMember -Function Publish-NavContainerApp

<# 
 .Synopsis
  Sync Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Sync-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter appName
  Name of app you want to install in the container
 .Example
  Install-NavApp -containerName test2 -appName myapp
#>
function Sync-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )
    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Synchronizing app $appFile"
        Sync-NavTenant -ServerInstance NAV -Tenant default -Force
        Sync-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully synchronized"
}
Export-ModuleMember -Function Sync-NavContainerApp

<# 
 .Synopsis
  Install Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Install-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to install the app (default navserver)
 .Parameter appName
  Name of app you want to install in the container
 .Example
  Install-NavApp -containerName test2 -appName myapp
#>
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
Export-ModuleMember -Function Install-NavContainerApp

<# 
 .Synopsis
  Uninstall Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Uninstall-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to uninstall the app (default navserver)
 .Parameter appName
  Name of app you want to uninstall in the container
 .Example
  Uninstall-NavApp -containerName test2 -appName myapp
#>
function UnInstall-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Uninstalling app $appName"
        Uninstall-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully uninstalled"
}
Export-ModuleMember -Function UnInstall-NavContainerApp

<# 
 .Synopsis
  Unpublish Nav App in Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Unpublish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to unpublish the app (default navserver)
 .Parameter appName
  Name of app you want to unpublish in the container
 .Example
  Unpublish-NavApp -containerName test2 -appName myapp
#>
function UnPublish-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appName)
        Write-Host "Unpublishing app $appName"
        Unpublish-NavApp -ServerInstance NAV -Name $appName
    } -ArgumentList $appName
    Write-Host -ForegroundColor Green "App successfully unpublished"
}
Export-ModuleMember -Function UnPublish-NavContainerApp

<# 
 .Synopsis
  Get Nav App Info from Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Get-NavAppInfo in the container
 .Parameter containerName
  Name of the container in which you want to enumerate apps (default navserver)
 .Example
  Get-NavContainerAppInfo -containerName test2
#>
function Get-NavContainerAppInfo {
    Param(
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { 
        Get-NavAppInfo -ServerInstance NAV
    } 
}
Export-ModuleMember -Function Get-NavContainerAppInfo

<# 
 .Synopsis
  Copy the NavSip.dll Crypto Provider from a Container and install it locally
 .Description
  The NavSip crypto provider is used when signing extensions
  Extensions cannot be signed inside the container, they need to be signed on the host.
  Beside the NavSip.dll you also need the SignTool.exe which you get with Visual Studio.
 .Parameter containerName
  Name of the container from which you want to copy and install the NavSip.dll (default is navserver)
 .Example
  Install-NAVSipCryptoProviderFromNavContainer
#>
function Install-NAVSipCryptoProviderFromNavContainer {
    Param(
        [string]$containerName = "navserver"
    )

    $msvcr120Path = "C:\Windows\System32\msvcr120.dll"
    if (!(Test-Path $msvcr120Path)) {
        Copy-FileFromNavContainer -containerName $containerName -ContainerPath $msvcr120Path
    }

    $navSip64Path = "C:\Windows\System32\NavSip.dll"
    $navSip32Path = "C:\Windows\SysWow64\NavSip.dll"

    RegSvr32 /u /s $navSip64Path
    RegSvr32 /u /s $navSip32Path

    Log "Copy NAV SIP crypto provider from container $containerName"
    Copy-FileFromNavContainer -containerName $containerName -ContainerPath $navSip64Path
    Copy-FileFromNavContainer -containerName $containerName -ContainerPath $navSip32Path

    RegSvr32 /s $navSip32Path
    RegSvr32 /s $navSip64Path
}
Export-ModuleMember -Function Install-NAVSipCryptoProviderFromNavContainer

<# 
 .Synopsis
  Replace navserver container with a different image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called navserver.
  Running this command will replace the container with a new container with a different (or the same) image.
 .Parameter imageName
  imageName you want to use to replace the navserver container
 .Parameter certificatePfxUrl
  Secure Url to certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter certificatePfxPassword
  Password for certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter publicDnsName
  Public Dns name (CNAME record) pointing to the host machine
 .Example
  Replace-NavServerContainer -imageName navdocker.azurecr.io/dynamics-nav:devpreview-september-finus
 .Example
  Replace-NavServerContainer -imageName navdocker.azurecr.io/dynamics-nav:devpreview-september-fingb -certificatePfxUrl <secureurl> -certificatePfxPassword <password> -publicDnsName myhost.navdemo.net
#>
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

    if (Test-NavContainer -containerName navserver) {
        Write-Host "Remove container navserver"
        Remove-NavContainerSession -containerName $containerName
        $containerId = Get-NavContainerId -containerName $containerName
        docker rm $containerId -f | Out-Null
    }
    
    $settingsScript = "c:\demo\settings.ps1"
    $settings = Get-Content -Path  $settingsScript
    0..($settings.Count-1) | % { if ($settings[$_].StartsWith('$navDockerImage = ', "OrdinalIgnoreCase")) { $settings[$_] = ('$navDockerImage = "'+$newImageName + '"') } }
    Set-Content -Path $settingsScript -Value $settings

    Write-Host -ForegroundColor Green "Setup new Nav container"
    . $SetupNavContainerScript
    . $setupDesktopScript
}
Export-ModuleMember -Function Replace-NavServerContainer

<# 
 .Synopsis
  Replace navserver container with the same image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called navserver.
  Running this command will replace the container with a new container using the same image - recreateing or refreshing the container.
 .Parameter certificatePfxUrl
  Secure Url to certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter certificatePfxPassword
  Password for certificate Pfx file to be used with the container (leave empty to create a self-signed certificate)
 .Parameter publicDnsName
  Public Dns name (CNAME record) pointing to the host machine
 .Example
  Recreate-NavServerContainer
 .Example
  Recreate-NavServerContainer -certificatePfxUrl <secureurl> -certificatePfxPassword <password> -publicDnsName myhost.navdemo.net
#>
function Recreate-NavServerContainer {
    Param(
        [string]$certificatePfxUrl = "", 
        [string]$certificatePfxPassword = "", 
        [string]$publicDnsName = ""
    )

    $imageName = Get-NavContainerImageName -containerName navserver
    Replace-NavServerContainer -imageName $imageName -certificatePfxUrl $certificatePfxUrl -certificatePfxPassword $certificatePfxPassword -publicDnsName $publicDnsName
}
Export-ModuleMember -Function Recreate-NavServerContainer

function New-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name, 
        [Parameter(Mandatory=$true)]
        [string]$TargetPath, 
        [string]$WorkingDirectory = "", 
        [string]$IconLocation = "", 
        [string]$Arguments = "",
        [string]$FolderName = "Desktop",
        [bool]$RunAsAdministrator = $true
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
    if ($RunAsAdministrator) {
        $bytes = [System.IO.File]::ReadAllBytes($filename)
        $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
        [System.IO.File]::WriteAllBytes($filename, $bytes)
    }
}
Export-ModuleMember New-DesktopShortcut

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
Export-ModuleMember Remove-DesktopShortcut

#region Print Welcome text
function Write-NavContainerHelperWelcomeText {
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
    Write-Host "Get-NavContainerIpAddress     Get IP Address to a Nav container"
    Write-Host "Get-NavContainerSharedFolders Get Shared Folders from a Nav container"
    Write-Host "Get-NavContainerPath          Get the path inside a Nav container to a shared file"
    Write-Host "Get-NavContainerName          Get the name of a Nav container"
    Write-Host "Get-NavContainerId            Get the Id of a Nav container"
    Write-Host "Test-NavContainer             Test whether a Nav container exists"
    Write-Host
    Write-Host -ForegroundColor Yellow "Container handling functions"
    Write-Host "New-CSideDevContainer         Create new C/SIDE development container"
    Write-Host "Remove-CSideDevContainer      Remove C/SIDE development container"
    Write-Host "Get-NavContainerSession       Create new session to a Nav container"
    Write-Host "Remove-NavContainerSession    Remove Nav container session"
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
    Write-Host "Install-NAVSipCryptoProviderFromNavContainer Install Nav Sip Crypto Provider locally from container to sign extensions"
    Write-Host
    Write-Host -ForegroundColor Yellow "Azure VM specific functions"
    Write-Host "Replace-NavServerContainer    Replace navserver (primary) container"
    Write-Host "Recreate-NavServerContainer   Recreate navserver (primary) container"
    Write-Host
    Write-Host -ForegroundColor White "Note: The Nav Container Helper is an open source project from http://www.github.com/microsoft/navcontainerhelper."
    Write-Host -ForegroundColor White "The project is released as-is, no warranty! Contributions are welcome, study the github repository for usage."
    Write-Host -ForegroundColor White "Report issues on http://www.github.com/microsoft/navcontainerhelper/issues."
    Write-Host
}
Export-ModuleMember Write-NavContainerHelperWelcomeText
#endregion Print Welcome text
