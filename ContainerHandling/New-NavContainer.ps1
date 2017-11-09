<# 
 .Synopsis
  Create or refresh a Nav container
 .Description
  Creates a new Nav container based on a Nav Docker Image
  Adds shortcut on the desktop for Web Client and Container PowerShell prompt
 .Parameter accept_eula
  Switch, which you need to specify if you accept the eula for running Nav on Docker containers (See https://go.microsoft.com/fwlink/?linkid=861843)
 .Parameter containerName
  Name of the new Nav container (if the container already exists it will be replaced)
 .Parameter devImageName
  Name of the image you want to use for your Nav container (default is to grab the imagename from the navserver container)
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
 .Parameter useSSL
  Include this switch if you want to use SSL (https) with a self-signed certificate
 .Parameter includeCSide
  Include this switch if you want to have Windows Client and CSide development environment available on the host
 .Parameter doNotExportObjectsToText
  Avoid exporting objects for baseline from the container (Saves time, but you will not be able to use the object handling functions without the baseline)
 .Parameter auth
  Set auth to Windows or NavUserPassword depending on which authentication mechanism your container should use
 .Parameter additionalParameters
  This allows you to transfer an additional number of parameters to the docker run
 .Parameter myscripts
  This allows you to specify a number of scripts you want to copy to the c:\run\my folder in the container (override functionality)
 .Example
  New-NavContainer -containerName test
 .Example
  New-NavContainer -containerName test -memoryLimit 3G -imageName "navdocker.azurecr.io/dynamics-nav:2017" -updateHosts
 .Example
  New-NavContainer -containerName test -imageName "navdocker.azurecr.io/dynamics-nav:2017" -myScripts @("c:\temp\AdditionalSetup.ps1") -AdditionalParameters @("-v c:\hostfolder:c:\containerfolder")
 .Example
  New-NavContainer -containerName test -adminPassword <mypassword> -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1" -imageName "navdocker.azurecr.io/dynamics-nav:devpreview-finus"
#>
function New-NavContainer {
    Param(
        [switch]$accept_eula,
        [switch]$accept_outdated,
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$imageName = "", 
        [string]$licenseFile = "",
        [string]$vmAdminUsername = (Get-DefaultVmAdminUsername),
        [SecureString]$adminPassword = (Get-DefaultAdminPassword),
        [string]$memoryLimit = "4G",
        [switch]$updateHosts,
        [switch]$useSSL,
        [switch]$includeCSide,
        [switch]$doNotExportObjectsToText,
        [ValidateSet('Windows','NavUserPassword')]
        [string]$auth='Windows',
        [string[]]$additionalParameters = @(),
        [string[]]$myScripts = @()
    )

    if (!$accept_eula) {
        throw "You have to accept the eula (See https://go.microsoft.com/fwlink/?linkid=861843) by specifying the -accept_eula switch to the function"
    }

    if ($containerName -eq "navserver") {
        throw "You cannot create a Nav container called navserver. Use Replace-NavServerContainer to replace the navserver container."
    }

    if ($includeCSide) {
        if ($licenseFile -eq "") {
            $licenseFile = "C:\DEMO\license.flf"
            if (!(Test-Path -Path $licenseFile)) {
                if ($doNotExportObjectsToText) {
                    $licenseFile = ""
                } else {
                    throw "You must specify a license file when creating a CSide Development container or use -doNotExportObjectsToText to avoid baseline generation."
                }
            }
        } elseif ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
        } elseif (!(Test-Path $licenseFile)) {
            throw "License file '$licenseFile' must exist in order to create a Developer Server Container."
        }
    }

    $myScripts | % {
        if (!(Test-Path $_ -PathType Leaf)) {
            throw "Script file $_ does not exist"
        }
    }

    if ($imageName -eq "") {
        if (!(Test-NavContainer -containerName navserver)) {
            throw "You need to specify the name of the docker image you want to use for your Nav container."
        }
        $imageName = Get-NavContainerImageName -containerName navserver
        $devCountry = Get-NavContainerCountry -containerOrImageName navserver
    } else {
        $imageId = docker images -q $imageName
        if (!($imageId)) {
            Write-Host "Pulling docker Image $imageName"
            docker pull $imageName
        }
        $devCountry = Get-NavContainerCountry -containerOrImageName $imageName
    }

    Write-Host "Creating Nav container $containerName"
    Write-Host "Using image $imageName"
    
    if ("$licenseFile" -ne "") {
        Write-Host "Using license file $licenseFile"
    }

    $navversion = Get-NavContainerNavversion -containerOrImageName $imageName
    Write-Host "NAV Version: $navversion"
    $version = [System.Version]($navversion.split('-')[0])
    $genericTag = Get-NavContainerGenericTag -containerOrImageName $imageName
    Write-Host "Generic Tag: $genericTag"
    $locale = Get-LocaleFromCountry $devCountry

    if (Test-NavContainer -containerName $containerName) {
        Remove-NavContainer $containerName -UpdateHosts:$UpdateHosts
    }

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    $myScripts | % {
        Copy-Item -Path $_ -Destination $myFolder -Force
    }
    
    if ("$licensefile" -eq "" -or $licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
        $containerLicenseFile = $licenseFile
    } else {
        Copy-Item -Path $licenseFile -Destination "$myFolder\license.flf" -Force
        $containerLicenseFile = "c:\run\my\license.flf"
    }

    if ($includeCSide) {
        $programFilesFolder = Join-Path $containerFolder "Program Files"
        New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

        # Clear modified flag on all objects
        'sqlcmd -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0"
        ' | Add-Content -Path "$myfolder\AdditionalSetup.ps1"

        # Enable Symbol loading at Server Startup
        if ($version.Major -gt 10) {
            if (!(Test-Path "$myfolder\SetupConfiguration.ps1")) {
                # If SetupConfiguration wasn't already overridden, we need to call base SetupConfiguration
                '. (Join-Path $runPath $MyInvocation.MyCommand.Name)' | Set-Content -Path "$myfolder\SetupConfiguration.ps1"
            }
            '$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
            $CustomConfig = [xml](Get-Content $CustomConfigFile)
            $enableSymbolLoadingAtServerStartupNode = $customConfig.SelectSingleNode("//appSettings/add[@key=''EnableSymbolLoadingAtServerStartup'']")
            if ($enableSymbolLoadingAtServerStartupNode) {
                $enableSymbolLoadingAtServerStartupNode.Value = "true"
                $CustomConfig.Save($CustomConfigFile)
            }
            ' | Add-Content -Path "$myfolder\SetupConfiguration.ps1"
        }
        
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
    }

    Write-Host "Creating container $containerName from image $imageName"

    $parameters = @(
                    "--name $containerName",
                    "--hostname $containerName",
                    "--env auth=$auth"
                    "--env username=$vmAdminUsername",
                    "--env ExitOnError=N",
                    "--env locale=$locale",
                    "--env licenseFile=""$containerLicenseFile""",
                    "--memory $memoryLimit",
                    "--volume ""${demoFolder}:$containerDemoFolder""",
                    "--volume ""${myFolder}:C:\Run\my""",
                    "--restart always"
                   )

    if ($useSSL) {
        $parameters += "--env useSSL=Y"
    } else {
        $parameters += "--env useSSL=N"
    }

    if ($includeCSide) {
        $parameters += "--volume ""${programFilesFolder}:C:\navpfiles"""
    }

    if ([System.Version]$genericTag -ge [System.Version]"0.0.3.0") {
        $passwordKeyFile = "$myfolder\aes.key"
        $passwordKey = New-Object Byte[] 16
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($passwordKey)
        try {
            Set-Content -Path $passwordKeyFile -Value $passwordKey
            $encPassword = ConvertFrom-SecureString -SecureString $adminPassword -Key $passwordKey
            
            $parameters += @(
                             "--env securePassword=$encPassword",
                             "--env passwordKeyFile=""$passwordKeyFile""",
                             "--env removePasswordKeyFile=Y"
                            )
            
            $parameters += $additionalParameters
        
            $id = DockerRun -accept_eula -accept_outdated:$accept_outdated -imageName $imageName -parameters $parameters
            Wait-NavContainerReady $containerName
        } finally {
            Remove-Item -Path $passwordKeyFile -Force -ErrorAction Ignore
        }
    } else {
        $plainPassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword)))
        $parameters += "--env password=""$plainPassword"""
        $parameters += $additionalParameters
        $id = DockerRun -accept_eula -accept_outdated:$accept_outdated -imageName $imageName -parameters $parameters
        Wait-NavContainerReady $containerName
    }

    if ($UpdateHosts) {
        $ip = Get-NavContainerIpAddress -containerName $containerName
        Write-Host "Add $ip $containerName to hosts"
        Update-Hosts -hostName $containerName -ip $ip
    }

    Write-Host "Create Desktop Shortcuts for $containerName"

    if ($useSSL) {
        $protocol = "https://"
    } else {
        $protocol = "http://"
    }
    New-DesktopShortcut -Name "$containerName Web Client" -TargetPath "$protocol${containerName}/NAV/" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    New-DesktopShortcut -Name "$containerName Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName cmd"
    New-DesktopShortcut -Name "$containerName PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1"

    if ($includeCSide) {
        $winClientFolder = (Get-Item "$programFilesFolder\*\RoleTailored Client").FullName
        $ps = '$customConfigFile = Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "CustomSettings.config"
        [System.IO.File]::ReadAllText($customConfigFile)'
        [xml]$customConfig = docker exec $containerName powershell $ps
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        $databaseServer = "$containerName"
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
        New-DesktopShortcut -Name "$containerName Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe"
        New-DesktopShortcut -Name "$containerName CSIDE" -TargetPath "$WinClientFolder\finsql.exe" -Arguments "servername=$databaseServer, Database=$databaseName, ntauthentication=yes"

        if (!$doNotExportObjectsToText) {
            
            # Include newsyntax if NAV Version is greater than NAV 2017
            0..($version.Major -gt 10) | % {
                $newSyntax = ($_ -eq 1)
                $suffix = ""
                if ($newSyntax) { $suffix = "-newsyntax" }
                $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"
                if (!(Test-Path $originalFolder)) {
                    # Export base objects
                    Export-NavContainerObjects -containerName $containerName `
                                               -objectsFolder $originalFolder `
                                               -filter "" `
                                               -adminPassword $adminPassword `
                                               -ExportToNewSyntax:$newSyntax
                }
            }
        }
    }
    Write-Host -ForegroundColor Green "Nav container $containerName successfully created"
}
Export-ModuleMember -function New-NavContainer
