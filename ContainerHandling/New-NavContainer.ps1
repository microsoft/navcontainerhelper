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
  Path or Secure Url of the licenseFile you want to use
 .Parameter credential
  Username and Password for the NAV Container
 .Parameter memoryLimit
  Memory limit for the container (default is unlimited for Windows Server host else 4G)
 .Parameter isolation
  Isolation mode for the container (default is process for Windows Server host else hyperv)
 .Parameter AuthenticationEmail
  AuthenticationEmail of the admin user of NAV
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
 .Parameter enableSymbolLoading
  Include this switch if you want to do development in both CSide and VS Code to have symbols automatically generated for your changes in CSide
 .Parameter doNotExportObjectsToText
  Avoid exporting objects for baseline from the container (Saves time, but you will not be able to use the object handling functions without the baseline)
 .Parameter assignPremiumPlan
  Assign Premium plan to admin user
 .Parameter alwaysPull
  Always pull latest version of the docker image
 .Parameter multitenant
  Setup container for multitenancy by adding this switch
 .Parameter restart
  Define the restart option for the container
 .Parameter auth
  Set auth to Windows, NavUserPassword or AAD depending on which authentication mechanism your container should use
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.). -1 means wait forever.
 .Parameter additionalParameters
  This allows you to transfer an additional number of parameters to the docker run
 .Parameter myscripts
  This allows you to specify a number of scripts you want to copy to the c:\run\my folder in the container (override functionality)
 .Example
  New-NavContainer -containerName test
 .Example
  New-NavContainer -containerName test -multitenant
 .Example
  New-NavContainer -containerName test -memoryLimit 3G -imageName "microsoft/dynamics-nav:2017" -updateHosts
 .Example
  New-NavContainer -containerName test -imageName "microsoft/dynamics-nav:2017" -myScripts @("c:\temp\AdditionalSetup.ps1") -AdditionalParameters @("-v c:\hostfolder:c:\containerfolder")
 .Example
  New-NavContainer -containerName test -credential (get-credential -credential $env:USERNAME) -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1" -imageName "microsoft/dynamics-nav:devpreview-finus"
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
        [string]$authenticationEMail = "",
        [string]$memoryLimit = "",
        [ValidateSet('','process','hyperv')]
        [string]$isolation = "",
        [string]$databaseServer = "",
        [string]$databaseInstance = "",
        [string]$databaseName = "",
        [System.Management.Automation.PSCredential]$databaseCredential = $null,
        [ValidateSet('None','Desktop','StartMenu','CommonStartMenu')]
        [string]$shortcuts='Desktop',
        [switch]$updateHosts,
        [switch]$useSSL,
        [switch]$includeCSide,
        [switch]$enableSymbolLoading,
        [switch]$doNotExportObjectsToText,
        [switch]$alwaysPull,
        [switch]$assignPremiumPlan,
        [switch]$multitenant,
        [switch]$includeTestToolkit,
        [ValidateSet('no','on-failure','unless-stopped','always')]
        [string]$restart='unless-stopped',
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string]$auth='Windows',
        [int]$timeout = 1800,
        [string[]]$additionalParameters = @(),
        $myScripts = @()
    )

    if (!$accept_eula) {
        throw "You have to accept the eula (See https://go.microsoft.com/fwlink/?linkid=861843) by specifying the -accept_eula switch to the function"
    }

    Check-NavContainerName -ContainerName $containerName

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

    $myScripts | ForEach-Object {
        if ($_ -is [string]) {
            if ($_.StartsWith("https://", "OrdinalIgnoreCase") -or $_.StartsWith("http://", "OrdinalIgnoreCase")) {
            } elseif (!(Test-Path $_)) {
                throw "Script directory or file $_ does not exist"
            }
        } elseif ($_ -isnot [Hashtable]) {
            throw "Illegal value in myScripts"
        }
    }

    $isServerHost = ((Get-ComputerInfo).OsProductType -eq "Server")


    $parameters = @()

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
    if (!$imageName.Contains(':')) {
        $imageName += ":latest"
    }
    $imageId = docker images -q $imageName
    if (!($imageId)) {
        $alwaysPull = $true
    }

    if ($alwaysPull) {
        Write-Host "Pulling docker Image $imageName"
        docker pull $imageName
    }

    if ($multitenant) {
        $parameters += "--env multitenant=Y"
    }

    $navDvdPath = $navDvdPath.ToLowerInvariant()
    $navDvdPathIsTemp = $false
    if ($navDvdPath.EndsWith(".zip")) {
        $navDvdPathIsTemp = $true

        $temp = Join-Path $ENV:TEMP ([System.Guid]::NewGuid().ToString())
        new-item -type directory -Path $temp | Out-Null
        if ($navDvdPath.StartsWith("http://") -or $navDvdPath.StartsWith("https://")) {
            Write-Host "Downloading DVD .zip file"
            Download-File -sourceUrl $navDvdPath -destinationFile "$temp.zip"
            Write-Host "Extracting DVD .zip file"
            Expand-Archive -Path "$temp.zip" -DestinationPath $temp
            Remove-Item -Path "$temp.zip"
        } else {
            Write-Host "Extracting DVD .zip file"
            Expand-Archive -Path $navDvdPath -DestinationPath $temp
        }
        $navDvdPath = $temp
    }

    if ("$navDvdPath" -ne "") {
        $navversion = (Get-Item -Path (Join-Path $navDvdPath "setup.exe")).VersionInfo.FileVersion
        $devCountry = $navDvdCountry
        $navtag = Get-NavVersionFromVersionInfo -VersionInfo $navversion

        $parameters += @(
                       "--label nav=$navtag",
                       "--label version=$navversion",
                       "--label country=$devCountry",
                       "--label cu="
                       )

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

    if ((!$doNotExportObjectsToText) -and ($version -lt [System.Version]"8.0.0.0")) {
        throw "PowerShell Cmdlets to export objects as text are not included before NAV 2015, please specify -doNotExportObjectsToText."
    }

    if ($multitenant -and ($version -lt [System.Version]"7.1.0.0")) {
        throw "Multitenancy is not supported in NAV 2013"
    }

    if ($multitenant -and [System.Version]$genericTag -lt [System.Version]"0.0.4.5") {
        throw "Multitenancy is not supported by images with generic tag prior to 0.0.4.5"
    }

    if ($auth -eq "AAD" -and [System.Version]$genericTag -lt [System.Version]"0.0.5.0") {
        throw "AAD authentication is not supported by images with generic tag prior to 0.0.5.0"
    }

    if (!$isServerHost -and "$isolation" -eq "process") {
        throw "Process isolation mode is only supported on Windows Server hosts"
    }

    # Remove if it already exists
    Remove-NavContainer $containerName

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction Ignore
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    $myScripts | ForEach-Object {
        if ($_ -is [string]) {
            if ($_.StartsWith("https://", "OrdinalIgnoreCase") -or $_.StartsWith("http://", "OrdinalIgnoreCase")) {
                $uri = [System.Uri]::new($_)
                $filename = [System.Uri]::UnescapeDataString($uri.Segments[$uri.Segments.Count-1])
                $destinationFile = Join-Path $myFolder $filename
                Download-File -sourceUrl $_ -destinationFile $destinationFile
                if ($destinationFile.EndsWith(".zip", "OrdinalIgnoreCase")) {
                    Write-Host "Extracting .zip file"
                    Expand-Archive -Path $destinationFile -DestinationPath $myFolder
                    Remove-Item -Path $destinationFile -Force
                }
            } elseif (Test-Path $_ -PathType Container) {
                Copy-Item -Path "$_\*" -Destination $myFolder -Recurse -Force
            } else {
                if ($_.EndsWith(".zip", "OrdinalIgnoreCase")) {
                    Expand-Archive -Path $_ -DestinationPath $myFolder
                } else {
                    Copy-Item -Path $_ -Destination $myFolder -Force
                }
            }
        } else {
            $hashtable = $_
            $hashtable.Keys | ForEach-Object {
                Set-Content -Path (Join-Path $myFolder $_) -Value $hashtable[$_]
            }
        }
    }
    
    if ("$licensefile" -eq "") {
        if ($includeCSide -and (!$doNotExportObjectsToText)) {
            throw "You must specify a license file when creating a CSide Development container or use -doNotExportObjectsToText to avoid baseline generation."
        }
        $containerlicenseFile = ""
    } elseif ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
        $licensefileUri = $licensefile
        $licenseFile = "$myFolder\license.flf"
        Download-File -sourceUrl $licenseFileUri -destinationFile $licenseFile
        $bytes = [System.IO.File]::ReadAllBytes($licenseFile)
        $text = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 100)
        if (!($text.StartsWith("Microsoft Software License Information"))) {
            Remove-Item -Path $licenseFile -Force
            throw "Specified license file Uri isn't a direct download Uri"
        }
        $containerLicenseFile = "c:\run\my\license.flf"
    } else {
        Copy-Item -Path $licenseFile -Destination "$myFolder\license.flf" -Force
        $containerLicenseFile = "c:\run\my\license.flf"
    }

    $parameters += @(
                    "--name $containerName",
                    "--hostname $containerName",
                    "--env auth=$auth"
                    "--env username=""$($credential.UserName)""",
                    "--env ExitOnError=N",
                    "--env locale=$locale",
                    "--env licenseFile=""$containerLicenseFile""",
                    "--env databaseServer=""$databaseServer""",
                    "--env databaseInstance=""$databaseInstance""",
                    "--volume ""${hostHelperFolder}:$containerHelperFolder""",
                    "--volume ""${myFolder}:C:\Run\my""",
                    "--restart $restart"
                   )

    if ("$memoryLimit" -eq "") {
        if (!$isServerHost) {
            $parameters += "--memory 4G"
        }
    } else {
        $parameters += "--memory $memoryLimit"
    }

    if ("$isolation" -ne "") {
        $parameters += "--isolation $isolation"
    }

    if ($version.Major -gt 11) {
        $parameters += "--env enableApiServices=Y"
    }

    if ("$databaseName" -ne "") {
        $parameters += "--env databaseName=""$databaseName"""
    }

    if ("$authenticationEMail" -ne "") {
        $parameters += "--env authenticationEMail=""$authenticationEMail"""
    }

    if ($includeCSide) {
        $programFilesFolder = Join-Path $containerFolder "Program Files"
        New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

        # Clear modified flag on all objects
        'if ($restartingInstance -eq $false -and $databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {
             sqlcmd -S ''localhost\SQLEXPRESS'' -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0" | Out-Null
         }' | Add-Content -Path "$myfolder\AdditionalSetup.ps1"

        if ($enableSymbolLoading -and $version.Major -gt 10) {
            $parameters += "--env enableSymbolLoading=Y"
        }
        
        if (Test-Path $programFilesFolder) {
            Remove-Item $programFilesFolder -Force -Recurse -ErrorAction Ignore
        }
        New-Item $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        
        ('if ($restartingInstance -eq $false) {
        Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
        $destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
        $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
        [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "$publicDnsName"
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServerInstance""]").value="NAV"
        if ($multitenant) {
            $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""TenantId""]").value="$TenantId"
        }
        if ($clientUserSettings.SelectSingleNode("//appSettings/add[@key=""ServicesCertificateValidationEnabled""]") -ne $null) {
            $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServicesCertificateValidationEnabled""]").value="false"
        }
        if ($clientUserSettings.SelectSingleNode("//appSettings/add[@key=""ClientServicesCertificateValidationEnabled""]") -ne $null) {
            $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCertificateValidationEnabled""]").value="false"
        }
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesPort""]").value="$publicWinClientPort"
        $acsUri = "$federationLoginEndpoint"
        if ($acsUri -ne "") {
            if (!($acsUri.ToLowerInvariant().Contains("%26wreply="))) {
                $acsUri += "%26wreply=$publicWebBaseUrl"
            }
        }
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ACSUri""]").value = "$acsUri"
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""DnsIdentity""]").value = "$dnsIdentity"
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCredentialType""]").value = "$Auth"
        $clientUserSettings.Save("$destFolder\ClientUserSettings.config")
        }') | Add-Content -Path "$myfolder\AdditionalSetup.ps1"
    }

    if ($assignPremiumPlan) {
        if (!(Test-Path -Path "$myfolder\SetupNavUsers.ps1")) {
            ('# Invoke default behavior
              . (Join-Path $runPath $MyInvocation.MyCommand.Name)
            ') | Set-Content -Path "$myfolder\SetupNavUsers.ps1"
        }
     
        ('Get-NavServerUser -serverInstance NAV -tenant default |? LicenseType -eq "FullUser" | ForEach-Object {
            $UserId = $_.UserSecurityId
            Write-Host "Assign Premium plan for $($_.Username)"
            $dbName = $DatabaseName
            if ($multitenant) {
                $dbName = $TenantId
            }
            sqlcmd -S ''localhost\SQLEXPRESS'' -d $DbName -Q "INSERT INTO [dbo].[User Plan] ([Plan ID],[User Security ID]) VALUES (''{8e9002c0-a1d8-4465-b952-817d2948e6e2}'',''$userId'')" | Out-Null
          }
        ') | Add-Content -Path "$myfolder\SetupNavUsers.ps1"
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
        ('
        . (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\driversetc\hosts" -hostname '+$containername+' -ipAddress $ip
        ') | Add-Content -Path "$myfolder\AdditionalOutput.ps1"
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
                                 "--env encryptionSecurePassword=$encDatabasePassword"
                                )
            }
            
            $parameters += $additionalParameters
        
            if (!(DockerDo -accept_eula -accept_outdated:$accept_outdated -detach -imageName $imageName -parameters $parameters)) {
                return
            }
            Wait-NavContainerReady $containerName -timeout $timeout
        } finally {
            Remove-Item -Path $passwordKeyFile -Force -ErrorAction Ignore
        }
    } else {
        $plainPassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
        $parameters += "--env password=""$plainPassword"""
        $parameters += $additionalParameters
        if (!(DockerDo -accept_eula -accept_outdated:$accept_outdated -detach -imageName $imageName -parameters $parameters)) {
            return
        }
        Wait-NavContainerReady $containerName -timeout $timeout
    }

    if ($navDvdPathIsTemp) {
        Remove-Item -Path $navDvdPath -Recurse -Force
    }

    Write-Host "Reading CustomSettings.config from $containerName"
    $ps = '$customConfigFile = Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "CustomSettings.config"
    [System.IO.File]::ReadAllText($customConfigFile)'
    [xml]$customConfig = docker exec $containerName powershell $ps

    if ($shortcuts -ne "None") {
        Write-Host "Creating Desktop Shortcuts for $containerName"
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']") -ne $null) {
            $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
            if ("$publicWebBaseUrl" -ne "") {
                $webClientUrl = "$publicWebBaseUrl"
                if ($multitenant) {
                    $webClientUrl += "?tenant=default"
                }
                New-DesktopShortcut -Name "$containerName Web Client" -TargetPath "$webClientUrl" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3" -Shortcuts $shortcuts
                if ($includeTestToolkit) {
                    if ($multitenant) {
                        $webClientUrl += "&page=130401"
                    } else {
                        $webClientUrl += "?page=130401"
                    }
                    New-DesktopShortcut -Name "$containerName Test Tool" -TargetPath "$webClientUrl" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3" -Shortcuts $shortcuts
                }
            }
        }
        New-DesktopShortcut -Name "$containerName Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName cmd" -Shortcuts $shortcuts
        New-DesktopShortcut -Name "$containerName PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1" -Shortcuts $shortcuts
    }

    if ([System.Version]$genericTag -lt [System.Version]"0.0.4.4") {
        if (Test-Path -Path "C:\windows\System32\t2embed.dll" -PathType Leaf) {
            Copy-FileToNavContainer -containerName $containerName -localPath "C:\windows\System32\t2embed.dll" -containerPath "C:\Windows\System32\t2embed.dll"
        }
    }

    $sqlCredential = $null
    if ($auth -eq "NavUserPassword") {
        $sqlCredential = New-Object System.Management.Automation.PSCredential ('sa', $credential.Password)
    }

    if ($includeTestToolkit) {
        Import-TestToolkitToNavContainer -containerName $containerName -sqlCredential $sqlCredential
    }

    if ($includeCSide) {
        $winClientFolder = (Get-Item "$programFilesFolder\*\RoleTailored Client").FullName
        New-DesktopShortcut -Name "$containerName Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-settings:ClientUserSettings.config" -Shortcuts $shortcuts

        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        if ($databaseServer -eq "localhost") {
            $databaseServer = "$containerName"
        }

        if ($databaseCredential -ne $null -and $databaseCredential -ne [System.Management.Automation.PSCredential]::Empty) {
            $ntauth="0"
        } elseif ($auth -eq "Windows") {
            $ntauth="1"
        } else {
            $ntauth="0"
        }
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
        $csideParameters = "servername=$databaseServer, Database=$databaseName, ntauthentication=$ntauth"

        $enableSymbolLoadingKey = $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']")
        if ($enableSymbolLoadingKey -ne $null -and $enableSymbolLoadingKey.Value -eq "True") {
            $csideParameters += ",generatesymbolreference=1"
        }

        New-DesktopShortcut -Name "$containerName CSIDE" -TargetPath "$WinClientFolder\finsql.exe" -Arguments "$csideParameters" -Shortcuts $shortcuts

        if (!$doNotExportObjectsToText) {
            
            # Include newsyntax if NAV Version is greater than NAV 2017
            0..($version.Major -gt 10) | ForEach-Object {
                $newSyntax = ($_ -eq 1)
                $suffix = ""
                if ($newSyntax) { $suffix = "-newsyntax" }
                $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"
                if (!(Test-Path $originalFolder)) {
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
