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
 .Parameter imageName
  Name of the image you want to use for your Nav container (default is to grab the imagename from the navserver container)
 .Parameter navDvdPath
  When you are spinning up a Generic image, you need to specify the NAV DVD path
 .Parameter navDvdCountry
  When you are spinning up a Generic image, you need to specify the country version (w1, dk, etc.)
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use (default c:\programdata\navcontainerhelper\license.flf)
 .Parameter credential
  Username and Password for the NAV Container
 .Parameter memoryLimit
  Memory limit for the container (default 4G)
 .Parameter databaseServer
  Name of database server when using external SQL Server (omit if using database inside the container)
 .Parameter databaseInstance
  Name of database instance when using external SQL Server (omit if using database inside the container)
 .Parameter databaseName
  Name of database to connect to when using external SQL Server (omit if using database inside the container)
 .Parameter databaseCredential
  Credentials for the database connection when using external SQL Server (omit if using database inside the container)
 .Parameter shortcuts
  Location where the Shortcuts will be placed. Can be either None, Desktop or StartMenu
 .Parameter updateHosts
  Include this switch if you want to update the hosts file with the IP address of the container
 .Parameter useSSL
  Include this switch if you want to use SSL (https) with a self-signed certificate
 .Parameter includeCSide
  Include this switch if you want to have Windows Client and CSide development environment available on the host
 .Parameter doNotExportObjectsToText
  Avoid exporting objects for baseline from the container (Saves time, but you will not be able to use the object handling functions without the baseline)
 .Parameter alwaysPull
  Always pull latest version of the docker image
 .Parameter restart
  Define the restart option for the container
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
  New-NavContainer -containerName test -credential (get-credential -credential $env:USERNAME) -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1" -imageName "navdocker.azurecr.io/dynamics-nav:devpreview-finus"
#>
function New-NavContainer {
    Param(
        [switch]$accept_eula,
        [switch]$accept_outdated,
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$imageName = "", 
        [string]$navDvdPath = "", 
        [string]$navDvdCountry = "w1",
        [string]$licenseFile = "",
        [System.Management.Automation.PSCredential]$Credential = $null,
        [string]$memoryLimit = "4G",
        [string]$databaseServer = "",
        [string]$databaseInstance = "",
        [string]$databaseName = "",
        [System.Management.Automation.PSCredential]$databaseCredential = $null,
        [ValidateSet('None','Desktop','StartMenu')]
        [string]$shortcuts='Desktop',
        [switch]$updateHosts,
        [switch]$useSSL,
        [switch]$includeCSide,
        [switch]$doNotExportObjectsToText,
        [switch]$alwaysPull,
        [ValidateSet('no','on-failure','unless-stopped','always')]
        [string]$restart='unless-stopped',
        [ValidateSet('Windows','NavUserPassword')]
        [string]$auth='Windows',
        [string[]]$additionalParameters = @(),
        [string[]]$myScripts = @()
    )

    if (!$accept_eula) {
        throw "You have to accept the eula (See https://go.microsoft.com/fwlink/?linkid=861843) by specifying the -accept_eula switch to the function"
    }

    if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
        if ($auth -eq "Windows") {
            $credential = get-credential -UserName $env:USERNAME -Message "Using Windows Authentication. Please enter your Windows credentials."
        } else {
            $credential = get-credential -Message "Using NavUserPassword Authentication. Please enter username/password for the Containter."
        }
        if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
            throw "You have to specify credentials for your Container"
        }
    }

    if ($includeCSide) {
        if ($licenseFile -eq "") {
            $licenseFile = "c:\programdata\navcontainerhelper\license.flf"
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
        if (!(Test-Path $_)) {
            throw "Script directory or file $_ does not exist"
        }
    }

    $devCountry = ""
    $navVersion = ""
    if ($imageName -eq "") {
        if ("$navDvdPath" -ne "") {
            $imageName = "microsoft/dynamics-nav:generic"
        } elseif (Test-NavContainer -containerName navserver) {
            $imageName = Get-NavContainerImageName -containerName navserver
        } else {
            $imageName = "microsoft/dynamics-nav:latest"
        }
    }
    $imageId = docker images -q $imageName
    if (!($imageId)) {
        $alwaysPull = $true
    }

    if ($alwaysPull) {
        Write-Host "Pulling docker Image $imageName"
        docker pull $imageName
    }

    if ("$navDvdPath" -ne "") {
        $navversion = (Get-Item -Path (Join-Path $navDvdPath "setup.exe")).VersionInfo.FileVersion
        $devCountry = $navDvdCountry
    } elseif ($devCountry -eq "") {
        $devCountry = Get-NavContainerCountry -containerOrImageName $imageName
    }

    Write-Host "Creating Nav container $containerName"
    Write-Host "Using image $imageName"
    
    if ("$licenseFile" -ne "") {
        Write-Host "Using license file $licenseFile"
    }

    if ($navVersion -eq "") {
        $navversion = Get-NavContainerNavversion -containerOrImageName $imageName
    }
    Write-Host "NAV Version: $navversion"
    $version = [System.Version]($navversion.split('-')[0])
    $genericTag = Get-NavContainerGenericTag -containerOrImageName $imageName
    Write-Host "Generic Tag: $genericTag"
    $locale = Get-LocaleFromCountry $devCountry

    if (Test-NavContainer -containerName $containerName) {
        Remove-NavContainer $containerName
    }

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction Ignore
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    $myScripts | % {
        if (Test-Path $_ -PathType Container) {
            Copy-Item -Path "$_\*" -Destination $myFolder -Recurse -Force
        } else {
            Copy-Item -Path $_ -Destination $myFolder -Force
        }
    }
    
    if ("$licensefile" -eq "" -or $licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
        $containerLicenseFile = $licenseFile
    } else {
        Copy-Item -Path $licenseFile -Destination "$myFolder\license.flf" -Force
        $containerLicenseFile = "c:\run\my\license.flf"
    }

    $parameters = @(
                    "--name $containerName",
                    "--hostname $containerName",
                    "--env auth=$auth"
                    "--env username=""$($credential.UserName)""",
                    "--env ExitOnError=N",
                    "--env locale=$locale",
                    "--env licenseFile=""$containerLicenseFile""",
                    "--env databaseServer=""$databaseServer""",
                    "--env databaseInstance=""$databaseInstance""",
                    "--memory $memoryLimit",
                    "--volume ""${hostHelperFolder}:$containerHelperFolder""",
                    "--volume ""${myFolder}:C:\Run\my""",
                    "--restart $restart"
                   )

    if ("$databaseName" -ne "") {
        $parameters += "--env databaseName=""$databaseName"""
    }

    if ($includeCSide) {
        $programFilesFolder = Join-Path $containerFolder "Program Files"
        New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

        # Clear modified flag on all objects
        'if ($restartingInstance -eq $false -and $databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {
             sqlcmd -S ''localhost\SQLEXPRESS'' -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0"
         }' | Add-Content -Path "$myfolder\AdditionalSetup.ps1"

        if ($version.Major -gt 10) {
            $parameters += "--env enableSymbolLoading=Y"
        }
        
        if (Test-Path $programFilesFolder) {
            Remove-Item $programFilesFolder -Force -Recurse -ErrorAction Ignore
        }
        New-Item $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        
        ('Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
        $destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
        $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
        [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "$publicDnsName"
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

    if ($useSSL) {
        $parameters += "--env useSSL=Y"
    } else {
        $parameters += "--env useSSL=N"
    }

    if ($includeCSide) {
        $parameters += "--volume ""${programFilesFolder}:C:\navpfiles"""
    }

    if ("$navDvdPath" -ne "") {
        $parameters += "--volume ""${navDvdPath}:c:\NAVDVD"""
    }

    if ($updateHosts) {
        $parameters += "--volume ""c:\windows\system32\drivers\etc:C:\driversetc"""
        Copy-Item -Path (Join-Path $PSScriptRoot "updatehosts.ps1") -Destination $myfolder -Force
        '
        . (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\driversetc\hosts" -hostname $hostname -ipAddress $ip
        ' | Add-Content -Path "$myfolder\AdditionalOutput.ps1"
    }

    if ([System.Version]$genericTag -ge [System.Version]"0.0.3.0") {
        $passwordKeyFile = "$myfolder\aes.key"
        $passwordKey = New-Object Byte[] 16
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($passwordKey)
        $containerPasswordKeyFile = "c:\run\my\aes.key"
        try {
            Set-Content -Path $passwordKeyFile -Value $passwordKey
            $encPassword = ConvertFrom-SecureString -SecureString $credential.Password -Key $passwordKey
            
            $parameters += @(
                             "--env securePassword=$encPassword",
                             "--env passwordKeyFile=""$containerPasswordKeyFile""",
                             "--env removePasswordKeyFile=Y"
                            )

            if ($databaseCredential -ne $null -and $databaseCredential -ne [System.Management.Automation.PSCredential]::Empty) {

                $encDatabasePassword = ConvertFrom-SecureString -SecureString $databaseCredential.Password -Key $passwordKey
                $parameters += @(
                                 "--env databaseUsername=$($databaseCredential.UserName)",
                                 "--env databaseSecurePassword=$encDatabasePassword"
                                )
            }
            
            $parameters += $additionalParameters
        
            $id = DockerRun -accept_eula -accept_outdated:$accept_outdated -imageName $imageName -parameters $parameters

            Wait-NavContainerReady $containerName
        } finally {
            Remove-Item -Path $passwordKeyFile -Force -ErrorAction Ignore
        }
    } else {
        $plainPassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
        $parameters += "--env password=""$plainPassword"""
        $parameters += $additionalParameters
        $id = DockerRun -accept_eula -accept_outdated:$accept_outdated -imageName $imageName -parameters $parameters
        Wait-NavContainerReady $containerName
    }

    Write-Host "Read CustomSettings.config from $containerName"
    $ps = '$customConfigFile = Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "CustomSettings.config"
    [System.IO.File]::ReadAllText($customConfigFile)'
    [xml]$customConfig = docker exec $containerName powershell $ps

    Write-Host "Create Desktop Shortcuts for $containerName"
    $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
    if ("$publicWebBaseUrl" -ne "") {
        New-DesktopShortcut -Name "$containerName Web Client" -TargetPath "$publicWebBaseUrl" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3" -Shortcuts $shortcuts
    }
    New-DesktopShortcut -Name "$containerName Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName cmd" -Shortcuts $shortcuts
    New-DesktopShortcut -Name "$containerName PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1" -Shortcuts $shortcuts

    if ($includeCSide) {
        $winClientFolder = (Get-Item "$programFilesFolder\*\RoleTailored Client").FullName
        New-DesktopShortcut -Name "$containerName Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe" -Shortcuts $shortcuts

        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        if ($databaseServer -eq "localhost") {
            $databaseServer = "$containerName"
        }

        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
        $csideParameters = "servername=$databaseServer, Database=$databaseName, ntauthentication=yes"

        $enableSymbolLoadingKey = $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']")
        if ($enableSymbolLoadingKey -ne $null -and $enableSymbolLoadingKey.Value -eq "True") {
            $csideParameters += ", generatesymbolreference=yes"
        }

        New-DesktopShortcut -Name "$containerName CSIDE" -TargetPath "$WinClientFolder\finsql.exe" -Arguments $csideParameters -Shortcuts $shortcuts

        if (!$doNotExportObjectsToText) {
            
            # Include newsyntax if NAV Version is greater than NAV 2017
            0..($version.Major -gt 10) | % {
                $newSyntax = ($_ -eq 1)
                $suffix = ""
                if ($newSyntax) { $suffix = "-newsyntax" }
                $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"
                if (!(Test-Path $originalFolder)) {
                    $sqlCredential = $null
                    if ($auth -eq "NavUserPassword") {
                        $sqlCredential = New-Object System.Management.Automation.PSCredential ('sa', $credential.Password)
                    }
                    # Export base objects
                    Export-NavContainerObjects -containerName $containerName `
                                               -objectsFolder $originalFolder `
                                               -filter "" `
                                               -sqlCredential $sqlCredential `
                                               -ExportToNewSyntax:$newSyntax
                }
            }
        }
    }
    Write-Host -ForegroundColor Green "Nav container $containerName successfully created"
}
Export-ModuleMember -function New-NavContainer
