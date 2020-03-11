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
                $(New-MenuItem -DisplayName "create a new template" -Script { Menu-CreateTemplate $file }),
                $(New-MenuItem -DisplayName "remove a template" -Script { Menu-RemoveTemplate $file }),
                $(Get-MenuSeparator),
                $(New-MenuItem -DisplayName "create a new container" -Script { Menu-CreateContainer $file }),
                $(New-MenuItem -DisplayName "update license" -Script { Menu-UpdateLicense $file }),
                $(New-MenuItem -DisplayName "backup database" -Script { Menu-BackupDatabase $file })
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
        if (($authType -notmatch "Windows") -or ($authType -notmatch "NavUserPassword")) {
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
                        Import-NavContainerLicense -containerName $selection.fullName -licenseFile $newLicense
                }
                else {
                        throw "Not a valid license file"
                }
        }
}

function Menu-BackupDatabase() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to backup its database" -OutputMode Single
        if ($selection) {
                Backup-NavContainerDatabases -containerName $selection.fullName

                $containerFolder = Join-Path $ExtensionsFolder $selection.fullName
                $bakFolder = $containerFolder
                $containerBakFolder = Get-NavContainerPath -containerName $selection.fullName -path $bakFolder -throw
                if (Test-Path -path $containerBakFolder) {
                        Invoke-Item -Path $containerBakFolder
                }
                else {
                        throw "Could not find extension folder"
                }
        }       
}

Export-ModuleMember -Function Show-BCCSAssistant