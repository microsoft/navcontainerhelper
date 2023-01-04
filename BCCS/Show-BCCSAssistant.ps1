function Config-UpdateModule([string]$moduleName) {
        if (Get-Module -ListAvailable -Name $moduleName) {
                Write-Log "Checking for Updates [$($moduleName)]..."
                Update-Module -Name $moduleName
        } 
        else {
                Write-Log "$($moduleName) could not be found."
                Write-Log "Installing $($moduleName)..."
                Install-Module -Name $moduleName
        }
}
function Config-UpdateAllModules() {
        Config-UpdateModule("DockerHelpers")
        Config-UpdateModule("psmenu")
        Config-UpdateModule("SqlServer")
}

Function GetAllContainersFromDocker {
        $containers = Get-DockerContainer | Where-Object { $_.Name -match "-" }
        $contObjList = @()
        foreach ($container in $containers) {
                $splitName = $container.Name.Split("-")
                $contObj = [PSCustomObject]@{
                        template = $splitName[0];
                        name     = $splitName[1];
                        fullName = $container.Name;
                        status   = $container.Status;
                }
                $contObjList += $contObj
        }
        return $contObjList
}

Function Get-OpenFile($title, $filter, $initialDirectory) { 
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
        Out-Null

        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.initialDirectory = $initialDirectory
        $OpenFileDialog.filter = $filter
        $OpenFileDialog.title = $title
        $OpenFileDialog.ShowDialog() | Out-Null
        $OpenFileDialog.filename
        $OpenFileDialog.ShowHelp = $true
}

Function Get-OpenFolder($title, $initialDirectory) {
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | 
        Out-Null

        $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
        $foldername.Description = $title
        $foldername.rootfolder = "MyComputer"
        $foldername.SelectedPath = $initialDirectory

        if ($foldername.ShowDialog() -eq "OK") {
                $folder += $foldername.SelectedPath
        }
        return $folder
}

class MyMenuOption {
        [String]$DisplayName
        [ScriptBlock]$Script

        [String]ToString() {
                Return $This.DisplayName
        }
}
function New-MenuItem([String]$DisplayName, [ScriptBlock]$Script) {
        $MenuItem = [MyMenuOption]::new()
        $MenuItem.DisplayName = $DisplayName
        $MenuItem.Script = $Script
        Return $MenuItem
}
function Show-BCCSAssistant {
        param (
                [string]$file = ""
        )

        Clear-Host
        Config-UpdateAllModules
        $file = Get-BCCSTemplateFile $file
        Write-Host ""
        $menuList = @(
                $(New-MenuItem -DisplayName "create a new container from a deployment file" -Script { Menu-CreateContainerFromDeployFile }), 
                $(Get-MenuSeparator),
                $(New-MenuItem -DisplayName "update license" -Script { Menu-UpdateLicense $file }),
                $(New-MenuItem -DisplayName "backup database" -Script { Menu-BackupDatabase $file }),
                $(New-MenuItem -DisplayName "change windows password" -Script { Menu-ChangePWD $file }),
                $(New-MenuItem -DisplayName "add current Windows user" -Script { Menu-AddCurrentUser $file }),
                $(Get-MenuSeparator),
                $(New-MenuItem -DisplayName "deploy single app" -Script { Menu-DeployApp }),
                $(New-MenuItem -DisplayName "deploy apps from folder" -Script { Menu-DeployAppsFromFolder })
                $(Get-MenuSeparator),
                $(New-MenuItem -DisplayName "create a new template" -Script { Menu-CreateTemplate $file }),
                $(New-MenuItem -DisplayName "remove a template" -Script { Menu-RemoveTemplate $file }),
                $(New-MenuItem -DisplayName "create a new container" -Script { Menu-CreateContainer $file }),
                $(Get-MenuSeparator),
                $(New-MenuItem -DisplayName "create desktop shortcut for the assistant" -Script { Menu-CreateDesktopShortcut })
                
                $(New-MenuItem -DisplayName "allow debugging AL code in RTC debugger" -Script { Menu-UnProtectNavAppSourceFiles })
        )    
        do {
                Write-Host ""
                Write-Host "================ Business Central Container Script ================"
                Write-Host "Press 'Esc' to quit.`n"
                $Chosen = Show-Menu -MenuItems $menuList
                if ($chosen) {
                        & $Chosen.Script
                }
        }
        until ($chosen -eq $null)
}

function Menu-CreateTemplate {
        param (
                [string]$file
        )

        Write-Host ""
        $prefix = Read-Host "Prefix [e.g.: 'BC365']"
        $name = Read-Host "Name [e.g. 'Business Central']"
        $authType = Read-Host "Auth Type [Windows or NavUserPassword]"
        if (($authType -notmatch "Windows") -and ($authType -notmatch "NavUserPassword")) {
                throw "Auth Type must be Windows or NavUserPassword"
        }

        $licenseFile = $null
        if (!$licenseFile) {
                $licenseFile = Get-OpenFile "Pick license file for $($prefix)" "License files (*.flf)|*.flf" $PSScriptRoot
        }

        $imageName = $null
        if (!$imageName) {
                $imageName = Get-BCCSImage | Out-GridView -Title "Select an image" -OutputMode Single 
                Write-Host "image Name = $($imageName)"
        }
        if ($imageName -eq "") {
                throw "Parameter imageName cannot be empty."
        }

        Write-Host ""
        Write-Log "Save the following template? (defaults to yes)"
        Write-Host ""
        Write-Host "Prefix`t`t" -NoNewline
        Write-Host $prefix -ForegroundColor Yellow
        Write-Host "Name`t`t" -NoNewline
        Write-Host $name -ForegroundColor Yellow
        Write-Host "License File`t" -NoNewline
        Write-Host $licenseFile -ForegroundColor Yellow
        Write-Host "Image`t`t" -NoNewline
        Write-Host $imageName -ForegroundColor Yellow
        Write-Host "Auth Type`t`t" -NoNewline
        Write-Host $authType -ForegroundColor Yellow
        Write-Host ""
    
        $ReadHost = Read-Host " ( y / n ) "
        Switch ($ReadHost) {
                Y { $Save = $true }
                N { $Save = $false }
                Default { $Save = $false }
        }
        if ($Save) {
                New-BCCSTemplate $prefix $name $imageName $licenseFile -file $file -auth $authType
        }
}

function Menu-RemoveTemplate {
        param (
                [string]$file
        )

        $template = Get-BCCSTemplate -file $file | Out-GridView -Title "Select a template to delete" -OutputMode Single
        if (!$template) {
                throw "No template selected"
        }
        Remove-BCCSTemplate $template.prefix -file $file
}

function Menu-CreateDesktopShortcut {
        $module = Join-Path $bccsScriptFolder -ChildPath BcContainerHelper.psm1
        $module = "`'$module`'"
        New-DesktopShortcut -Name "BCCS Assistant" -TargetPath "PowerShell.exe" -Arguments "-NoExit -Command `"& { Import-Module $module; Show-BCCSAssistant }`"" -Shortcuts Desktop -RunAsAdministrator
        Write-Log "Created desktop shortcut 'BCCS Assistant'"
}

function Menu-CreateContainerFromDeployFile {
        $deployFile = Get-OpenFile "Choose a deployment file to create a container from" "Deployment file (deploy.json)|deploy.json" $PSScriptRoot
        if (!$deployFile) {
                throw "No deployment file selected"
        }

        $params = @{
                'file' = $deployFile;
        }

        Write-host "Windows or NavUserPassword? (defaults to Windows)" -ForegroundColor Yellow
        $ReadHost = Read-Host " ( w / n ) "
        Switch ($ReadHost) {
                W { $params += @{'auth' = 'Windows' } }
                N { $params += @{'auth' = 'NavUserPassword' } }
                Default { $params += @{'auth' = 'Windows' } }
        }

        Write-Host "Do you want to use a local SQL Server Instance ?" -ForegroundColor Yellow
        $ReadHost = Read-Host "( y / n)"
        Switch ($ReadHost) {
                Y { 
                        $UseLocalSql = $true
                        $UseBackup = $false 
                }
                N { $UseLocalSql = $false }
                default { $UseLocalSql = $false}
        }

        if($UseLocalSql -eq $false){
                Write-host "Use database backup? (defaults to no)" -ForegroundColor Yellow
                $ReadHost = Read-Host " ( y / n ) "
                Switch ($ReadHost) {
                        Y { $UseBackup = $true }
                        N { $UseBackup = $false }
                        Default { $UseBackup = $false }
                }
        }

        Write-host "Use license file for creation? (defaults to no)" -ForegroundColor Yellow
        $ReadHost = Read-Host " ( y / n ) "
        Switch ($ReadHost) {
                Y { $UseLicense = $true }
                N { $UseLicense = $false }
                Default { $UseLicense = $false }
        }

        Write-host "Use HyperV (with 8GB RAM) instead of process isolation? (defaults to no)" -ForegroundColor Yellow
        Write-Host "NOTE: Process Isolation can cause issues with the Windows Activation."
        $ReadHost = Read-Host " ( y / n ) "
        Switch ($ReadHost) {
                Y { $params += @{'isolation' = 'hyperv' } }
                N { $params += @{'isolation' = 'process' } }
                Default { $params += @{'isolation' = 'process' } }
        }
        
        Write-Host ""
        $suffix = Read-Host "Please enter a suffix (e.g. 'TEST' or 'DEV' -> added to the prefix defined in the deploy file)"
        if ($suffix) {
                $params += @{'containerSuffix' = $suffix }
        }
                
        if ($UseBackup) {
                $dbFile = Get-OpenFile "Pick database backup" "Database Backup files (*.bak)|*.bak" $PSScriptRoot
                if ($dbFile) {
                        $params += @{'databaseBackup' = $dbFile }
                }
        }
        if($UseLocalSql) {
                $sqlServerCredentials = get-credential -Message "Enter sql sa credentials"

                $sqlServerInstance = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances | Out-GridView -Title "Select a sql server instance to use" -OutputMode Single
                $databaseName =Invoke-Sqlcmd -ServerInstance "localhost\$sqlServerInstance" -Query 'SELECT name FROM master.sys.databases WHERE name NOT IN (''master'', ''tempdb'', ''model'', ''msdb'');' | Out-GridView -Title "Select a database to use" -OutputMode Single

                if(($null -eq $sqlServerInstance) -or ($null -eq $databaseName)){
                        Write-Error -Message "No sql server or database selected! Process abort" -ErrorAction Stop
                }

                $asm = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")
                $wmi = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' localhost
                $tcp = $wmi.ServerInstances[$sqlServerInstance].ServerProtocols['Tcp']
                if (-not $tcp.IsEnabled) {
                        Write-Error "The SQL Server Instance '$sqlServerInstance' is not configured for TCP/IP connections."
                }
                $sqlServerInstancePort = $tcp.IPAddresses["IPAll"].IPAddressProperties["TcpDynamicPorts"].Value
                if ([String]::IsNullOrEmpty($sqlServerInstancePort)) {
                        Write-Error "Unable to find the port for SQL Server Instance '$sqlServerInstance'"
                }
                        Write-Host "SQL Server Instance '$sqlServerInstance' is listening on port '$sqlServerInstancePort'."

                # check firewall rule
                $firewallRule = Get-NetFirewallRule -Direction Inbound -Enabled true | Where-Object Name -CIn (Get-NetFirewallPortFilter | Where-Object ({($_.LocalPort -icontains $sqlServerInstancePort) -and ($_.Protocol -eq 'TCP')})).InstanceID
                if (-not $firewallRule) {
                Write-Host "Firewall rule is missing. Creating a new firewall rule to allow connections at port $sqlServerInstancePort"
                        $firewallRule = New-NetFirewallRule -DisplayName "Allow connections to SQL Server Instance $sqlServerInstance" -Direction Inbound -LocalPort $sqlServerInstancePort -Protocol TCP -Action Allow
                } else {
                        Write-Host "Firewall rule to allow connections at port $sqlServerInstancePort exists."
                }
                # check tenant id
                $queryParams = @{ 'ErrorAction' = 'Ignore'; 'ServerInstance' = "localhost\$sqlServerInstance" }
                if ($sqlServerCredentials) {
                        $queryParams.Add('Username', $sqlServerCredentials.UserName)
                        $queryParams.Add('Password', ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlServerCredentials.Password))))
                }
                $query = 'SELECT TOP (1) tenantid FROM ['+$databaseName.name +'].[dbo].[$ndo$tenantproperty] WHERE tenantid IS NOT NULL'
                $tenantId = (Invoke-Sqlcmd @queryParams -Query $query)[0]
                if ([String]::IsNullOrEmpty($tenantId)) {
                        Write-Error "Tenant Id is not defined for database '$databaseName.name'"
                }
                $sqlServerInstanceConnection = "host.containerhelper.internal,$sqlServerInstancePort"

                $params.Add('databaseServer', $sqlServerInstanceConnection)
                $params.Add('databaseInstance', '')
                $params.Add('databaseName', $databaseName.name)
                $params.Add('databaseCredential', $sqlServerCredentials)            
        }

        if ($UseLicense) {
                $licenseFile = Get-OpenFile "Pick database license" "License files (*.flf)|*.flf" $PSScriptRoot
                if ($licenseFile) {
                        $params += @{'licenseFile' = $licenseFile }
                }
        }

        Write-Log "Creating container from assistant..."
        New-BcContainerFromDeployFile @params
}

function Menu-CreateContainer {
        param (
                [string]$file
        )

        $template = Get-BCCSTemplate -file $file | Out-GridView -Title "Select a template to use" -OutputMode Single
        if (!$template) {
                throw "No template selected"
        }
        $dbFile = $null
        Write-Host ""
        $containerName = Read-Host "Please enter a name (e.g. 'TEST' or 'DEV' -> added to the temp. prefix)"
        Write-host "Use database backup? (defaults to no)" -ForegroundColor Yellow
        $ReadHost = Read-Host " ( y / n ) "
        Switch ($ReadHost) {
                Y { $UseBackup = $true }
                N { $UseBackup = $false }
                Default { $UseBackup = $false }
        }
        if ($UseBackup) { 
                $dbFile = Get-OpenFile "Pick database backup for $($containerName)" "Database Backup files (*.bak)|*.bak" $PSScriptRoot
                New-BCCSContainerFromTemplate $template.prefix $containerName $dbFile -file $file
        }
        else {
                New-BCCSContainerFromTemplate $template.prefix $containerName -file $file
        }
}
function Menu-UpdateLicense() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to update its license" -OutputMode Single
        if ($selection) {
                $newLicense = Get-OpenFile "Pick new license file to upload" "License files (*.flf)|*.flf" $PSScriptRoot
                if (Test-Path -path $newLicense) {
                        Import-BcContainerLicense -containerName $selection.fullName -licenseFile $newLicense
                }
                else {
                        throw "Not a valid license file"
                }
        }
}

function Menu-BackupDatabase() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to backup its database" -OutputMode Single
        if ($selection) {
                Backup-BcContainerDatabases -containerName $selection.fullName

                $containerFolder = Join-Path $ExtensionsFolder $selection.fullName
                $bakFolder = $containerFolder
                $containerBakFolder = Get-BcContainerPath -containerName $selection.fullName -path $bakFolder -throw
                if (Test-Path -path $containerBakFolder) {
                        Invoke-Item -Path $containerBakFolder
                }
                else {
                        throw "Could not find extension folder"
                }
        }       
}

function Menu-ChangePWD() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to change your password in it" -OutputMode Single
        if ($selection) {
                Invoke-ScriptInBCContainer -containerName $selection.fullName -scriptblock {
                        Param($Username)
                        $Password = Read-Host "Enter the new password" -AsSecureString
                        Get-LocalUser -Name $Username -ErrorAction Stop | Set-LocalUser -Password $Password -ErrorAction Stop
                        Write-Host "Password changed for user $Username!" -ForegroundColor Green
                } -argumentList $env:USERNAME
        }       
}

function Menu-AddCurrentUser() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to add your User to its NAV/BC service" -OutputMode Single
        if ($selection) {
                New-BcContainerBcUser -WindowsAccount $env:USERNAME -containerName $selection.FullName -PermissionSetId SUPER 
                Write-Log "Added user $env:USERNAME to $($selection.FullName)!"
        }       
}

function Menu-UnProtectNavAppSourceFiles() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to set ProtectNavAppSourceFiles to false for" -OutputMode Single
        if ($selection) {
                Invoke-ScriptInBCContainer -containerName $selection.FullName -scriptblock {
                        $server = Get-Service | Where-Object Name -match Dynamics | Select-Object -ExpandProperty Name
                        try {
                                Set-NAVServerConfiguration -ServerInstance $server -KeyName ProtectNavAppSourceFiles -KeyValue false -ApplyTo all
                                Write-Host "Successfully set ProtectNavAppSourceFiles to false for instance $server"
                        }
                        catch {
                                Write-Host "Could not set ProtectNavAppSourceFiles for instance $server"
                        }
                }
        }       
}

function Menu-DeployAppsFromFolder() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to install apps into" -OutputMode Single
        if ($selection) {
                $appFolder = Get-OpenFolder "Pick folder with apps to install into $($selection.FullName)" $PSScriptRoot
                if (Test-Path -path $appFolder) {
                        Deploy-AppsFromFolder -containerName $selection.fullName -folderPath $appFolder
                }
                else {
                        throw "Not a valid folder"
                }
        }
}

function Menu-DeployApp() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to install an app into" -OutputMode Single
        if ($selection) {
                $appFile = Get-OpenFile "Pick app to install" "App files (*.app)|*.app" $PSScriptRoot
                if (Test-Path -path $appFile) {
                        Publish-BCContainerApp -containerName $selection.fullName -appFile $appFile -skipVerification -sync -install
                }
                else {
                        throw "Not a valid app file"
                }
        }
}

function Deploy-AppsFromFolder($containerName, $folderPath) {
        # Input
        [string] $syncMode = "Add"
        [bool] $unpublishOtherVersions = $true

        # Code
        $destinationPath = "C:\app-deployment"

        #Create Destination Path Folder
        Invoke-ScriptInBcContainer $containerName -scriptblock { Param($destinationPath)
                New-Item -ItemType Directory -Path $destinationPath -Force
        } -argumentList $destinationPath

        Get-ChildItem -Path $folderPath -Filter "*.app" -Recurse | ForEach-Object {
                $containerAppFile = Join-Path $destinationPath $_
                $appFile = $_.FullName

                try {
                        Copy-FileToBcContainer $containerName -localPath $appFile -containerPath $containerAppFile
                }
                catch {
                        docker cp $appFile "$containerName`:$containerAppFile"
                }
        }

        Invoke-ScriptInBcContainer $containerName -scriptblock {
                Param(
                        $destinationPath,
                        $syncMode,
                        $unpublishOtherVersions
                )
        
                $script:appsToInstall = @()
                $script:appPathsToInstall = @()

                function AddAnApp {
                        Param($anApp, $appPath) 
                        $alreadyAdded = $script:appsToInstall | Where-Object { $_.AppId -eq $anApp.AppId }
                        if (-not ($alreadyAdded)) {
                                AddDependencies -anApp $anApp
                                $script:appsToInstall += $anApp
                                $script:appPathsToInstall += $appPath
                        }
                }
        
                function AddDependency {
                        Param($dependency)
                        $dependentApp = $appInfos.Keys | Where-Object { $_.AppId -eq $dependency.AppId }
                        if ($dependentApp) {
                                AddAnApp -anApp $dependentApp -appPath $appInfos.Item($dependentApp)
                        }
                }
        
                function AddDependencies {
                        Param($anApp)
                        if (($anApp) -and ($anApp.Dependencies)) {
                                $anApp.Dependencies | % { AddDependency -dependency $_ }
                        }
                }

                Import-Module "C:\Program Files\Microsoft Dynamics Nav\*\Service\NavAdminTool.ps1" | Out-Null
                $serverInstance = "BC"
        
                $appInfos = @{}
                Get-ChildItem -Path $destinationPath -Filter "*.app" | ForEach-Object {
                        $appInfo = Get-NavAppInfo -Path $_.FullName
                        if (!$appInfos.ContainsKey($appInfo)) {
                                $appInfos.Add($appInfo, $_.FullName)
                        }
                }

                $appInfos.GetEnumerator() | % {
                        AddAnApp -anApp $_.Key -appPath $_.Value
                }
        
                Write-Host "Using following Dependency Tree:"

                $script:appsToInstall | % {
                        Write-Host "- $($_.Name)"
                }
        
                function Get-ExistingDependencies {
                        Param($baseApp)
                        $publishedApps = Get-NAVAppInfo -ServerInstance $serverInstance -Tenant "default" -TenantSpecificProperties
                        foreach ($publishedApp in $publishedApps) {
                                if ($publishedApp.IsInstalled) {
                                        $detailedAppInfo = Get-NAVAppInfo -ServerInstance $serverInstance -Tenant "default" -TenantSpecificProperties -Name $publishedApp.Name -Publisher $publishedApp.Publisher -Version $publishedApp.Version
                                        foreach ($dependency in $detailedAppInfo.Dependencies) {
                                                if ($dependency.AppId -eq $baseApp.AppId) {
                                                        $script:dependentApps += $detailedAppInfo
                                                        Get-ExistingDependencies -baseApp $detailedAppInfo
                                                }
                                        }
                                }
                        }
                }

                $script:appPathsToInstall | % {
                        $appPath = $_
                        Write-Host "Starting Installation from Path: $appPath"
            
                        $appInfo = Get-NavAppInfo -Path $appPath
        
                        $script:dependentApps = @()
                        Write-Host "Retrieving Dependencies for $($appInfo.Name)"
                        Get-ExistingDependencies -baseApp $appInfo

                        $skipInstallation = $false
                        $previousAppInfo = $null
                        Get-NAVAppInfo $serverInstance -Tenant default -TenantSpecificProperties -Name $appInfo.Name -Publisher $appInfo.Publisher | Where-Object {
                                if ($_.IsInstalled) {
                                        if ($appInfo.Version -le $_.Version) {
                                                Write-Warning "New Version $($appInfo.Version) is lower or equal to the previously installed Version $($_.Version) of the App $($_.Name) --> Skipping $($_.Name)"
                                                $skipInstallation = $true
                                        }
                                        else {
                                                $previousAppInfo = $_
                                                Write-Host "Uninstalling $($_.Name) with Version $($_.Version)"
                                                Uninstall-NAVApp $serverInstance -Name $_.Name -Publisher $_.Publisher -Version $_.Version -Force
                                        }
                                }
                        }

                        if (!$skipInstallation) {
                                try {
                                        Write-Host "Installing $($appInfo.Name) with Version $($appInfo.Version)"
                                        Publish-NAVApp -ServerInstance $serverInstance -Path $appPath -SkipVerification
                                        Sync-NAVApp $serverInstance -Name $appInfo.Name -Publisher $appInfo.Publisher -Version $appInfo.Version -Mode $syncMode -Force
                                        Start-NAVAppDataUpgrade $serverInstance -Name $appInfo.Name -Publisher $appInfo.Publisher -Version $appInfo.Version -ErrorAction "Ignore"
                                        Install-NavApp $serverInstance -Name $appInfo.Name -Publisher $appInfo.Publisher -Version $appInfo.Version
                                        Write-Host "Successfully installed $($appInfo.Name) with Version $($appInfo.Version)"
                                }
                                catch {
                                        if ($previousAppInfo) {
                                                Write-Host "Re-installing previous Version $($previousAppInfo.Version) of $($previousAppInfo.Name) due to failed Installation of the newer version"
                                                Install-NavApp $serverInstance -Name $previousAppInfo.Name -Publisher $previousAppInfo.Publisher -Version $previousAppInfo.Version
                                        }
                    
                                        $installationError = $_
                                }

                                foreach ($dependentApp in $script:dependentApps) {
                                        Write-Host "Re-installing Dependency $($dependentApp.Name) with Version $($dependentApp.Version)"
                                        Install-NAVApp $serverInstance -Name $dependentApp.Name -Publisher $dependentApp.Publisher -Version $dependentApp.Version -Force
                                }

                                if ($installationError) {
                                        throw "Installation of $($appInfo.Name) failed: $installationError"
                                }

                                if ($unpublishOtherVersions) {
                                        Write-Host "Unpublishing other Versions of App $($appInfo.Name)"
                                        $unpublishableApps = Get-NavAppInfo -ServerInstance $serverInstance -Name $appInfo.Name
                                        foreach ($unpublishableApp in $unpublishableApps) {
                                                if ($unpublishableApp.Version -ne $appInfo.Version) {
                                                        Unpublish-NAVApp -ServerInstance $serverInstance -Name $unpublishableApp.Name -Version $unpublishableApp.Version
                                                }
                                        }
                                }
                        }
                }

                Write-Host "Removing Folder $destinationPath"
                Remove-Item $destinationPath -Force -Recurse
        } -argumentList $destinationPath, $syncMode, $unpublishOtherVersions
}

Export-ModuleMember -Function Show-BCCSAssistant