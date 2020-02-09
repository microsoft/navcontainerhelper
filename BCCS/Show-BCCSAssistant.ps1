
function Write-Log($message) {
        $time = "[" + (Get-Date).Hour + ":" + (Get-Date).Minute + ":" + (Get-Date).Second + "]"
        Write-Host $time $message -ForegroundColor Yellow
}

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
                $contObj = New-Object Container
                $contObj.template = $splitName[0]
                $contObj.name = $splitName[1]
                $contObj.fullName = $container.Name
                $contObj.status = $container.Status
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
                [string]$Title = 'Business Central Container Script'
        )
        Config-UpdateAllModules
        $menuList = @(
                $(New-MenuItem -DisplayName "create a new template" -Script { Menu-CreateTemplate }),
                $(New-MenuItem -DisplayName "remove a template" -Script { Menu-RemoveTemplate }),
                $(Get-MenuSeparator),
                $(New-MenuItem -DisplayName "create a new container" -Script { Menu-CreateContainer }),
                $(New-MenuItem -DisplayName "update license" -Script { Menu-UpdateLicense })
        )    
        #Clear-Host
        do {
                Write-Host ""
                Write-Host "================ $Title ================"
                Write-Host "Press 'Esc' to quit.`n"
                $Chosen = Show-Menu -MenuItems $menuList
                if ($chosen) {
                        & $Chosen.Script
                }
        }
        until ($chosen -eq $null)
}

function Menu-CreateTemplate {
        Write-Host ""
        $prefix = Read-Host "Prefix [e.g.: 'BC365']"
        $name = Read-Host "Name [e.g. 'Business Central']"

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
        Write-Host "Prefix = " -NoNewline
        Write-Host $prefix -ForegroundColor Yellow
        Write-Host "Name = " -NoNewline
        Write-Host $name -ForegroundColor Yellow
        Write-Host "License File = " -NoNewline
        Write-Host $licenseFile -ForegroundColor Yellow
        Write-Host "Image = " -NoNewline
        Write-Host $imageName -ForegroundColor Yellow
        Write-Host ""
    
        $ReadHost = Read-Host " ( y / n ) "
        Switch ($ReadHost) {
                Y { $Save = $true }
                N { $Save = $false }
                Default { $Save = $false }
        }
        if ($Save) {
                New-BCCSTemplate $prefix $name $imageName $licenseFile
        }
}

function Menu-RemoveTemplate {
        $template = Get-BCCSTemplate | Out-GridView -Title "Select a template to delete" -OutputMode Single
        if (!$template) {
                throw "No template selected"
        }
        Remove-BCCSTemplate $template.prefix
}

function Menu-CreateContainer {
        $template = Get-BCCSTemplate | Out-GridView -Title "Select a template to use" -OutputMode Single
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
                New-BCCSContainerFromTemplate $template.prefix $containerName $dbFile
        }
        else {
                New-BCCSContainerFromTemplate $template.prefix $containerName 
        }
}
function Menu-UpdateLicense() {
        $selection = GetAllContainersFromDocker | Out-GridView -Title "Select a container to update its license" -OutputMode Single
        if ($selection) {
                $newLicense = Get-OpenFile "Pick new license file to upload" "License files (*.flf)|*.flf" $PSScriptRoot
                if (Test-Path -path $newLicense) {
                        Import-NavContainerLicense -containerName $selection.Name -licenseFile $newLicense
                }
                else {
                        throw "Not a valid license file"
                }
        }
}

Export-ModuleMember -Function Show-BCCSAssistant