Param(
    [switch] $skipContainerHelperCheck,
    [string] $predefinedpw = 'P@ssw0rd'
)

# create script for running docker

$ErrorActionPreference = "stop"

function Select-Value {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $title,
        [Parameter(Mandatory=$false)]
        [string] $description,
        [Parameter(Mandatory=$true)]
        $options,
        [Parameter(Mandatory=$false)]
        [string] $default = "",
        [Parameter(Mandatory=$true)]
        [string] $question,
        [switch] $doNotClearHost = ($host.name -ne "ConsoleHost"),
        [switch] $writeAnswer = ($host.name -ne "ConsoleHost"),
        [switch] $previousStep
    )

    if (!$doNotClearHost) {
        Clear-Host
    }

    if ($title) {
        Write-Host -ForegroundColor Yellow $title
        Write-Host
    }
    if ($description) {
        Write-Host $description
        Write-Host
    }
    $offset = 0
    $defaultChr = -1
    $keys = @()
    $values = @()

    $options.GetEnumerator() | ForEach-Object {
        Write-Host -ForegroundColor Yellow "$([char]($offset+97)) " -NoNewline
        $keys += @($_.Key)
        $values += @($_.Value)
        if ($_.Key -eq $default) {
            Write-Host -ForegroundColor Yellow $_.Value
            $defaultAnswer = $offset
        }
        else {
            Write-Host $_.Value
        }
        $offset++     
    }
    Write-Host
    if ($script:thisStep -lt 100) {
        if (($default) -and !$script:acceptDefaults) {
            Write-Host -ForegroundColor Yellow "!" -NoNewline
            Write-Host " accept default answers for the remaining questions"
        }
        if ($previousStep) {
            Write-Host -ForegroundColor Yellow "x" -NoNewline
            Write-Host " start over"
            Write-Host -ForegroundColor Yellow "z" -NoNewline
            Write-Host " go back"
        }
        if (($default) -or ($previousStep)) {
            Write-Host
        }
    }
    $answer = -1
    do {
        Write-Host "$question " -NoNewline
        if ($defaultAnswer -ge 0) {
            Write-Host "(default $([char]($defaultAnswer + 97))) " -NoNewline
        }
        if ($script:acceptDefaults -and $defaultAnswer -ge 0) {
            $selection = ""
        }
        else {
            $selection = (Read-Host).ToLowerInvariant()
        }
        if ($selection -eq "!" -and ($default)) {
            $selection = ""
            $script:acceptDefaults = $true
            Write-Host $defaultAnswer
        }
        if ($previousStep) {
            if ($selection -eq "x") {
                if ($writeAnswer) {
                    Write-Host
                    Write-Host -ForegroundColor Green "Start over selected"
                    Write-Host
                }
                $script:acceptDefaults = $false
                $script:wizardStep = 0
                $script:prevSteps = New-Object System.Collections.Stack
                $script:prevSteps.Push(1)
                return "Back"
            }
            if ($selection -eq "z") {
                if ($writeAnswer) {
                    Write-Host
                    Write-Host -ForegroundColor Green "Back selected"
                    Write-Host
                }
                $script:acceptDefaults = $false
                $script:wizardStep = $script:prevSteps.Pop()
                return "Back"
            }
        }
        if ($selection -eq "") {
            if ($defaultAnswer -ge 0) {
                $answer = $defaultAnswer
            }
            else {
                Write-Host -ForegroundColor Red "No default value exists. " -NoNewline
            }
        }
        else {
            if (($selection.Length -ne 1) -or (([int][char]($selection)) -lt 97 -or ([int][char]($selection)) -ge (97+$offset))) {
                Write-Host -ForegroundColor Red "Illegal answer. " -NoNewline
            }
            else {
                $answer = ([int][char]($selection))-97
            }
        }
        if ($answer -eq -1) {
            if ($offset -eq 2) {
                Write-Host -ForegroundColor Red "Please answer one letter, a or b"
            }
            else {
                Write-Host -ForegroundColor Red "Please answer one letter, from a to $([char]($offset+97-1))"
            }
        }
    } while ($answer -eq -1)

    if ($writeAnswer) {
        Write-Host
        Write-Host -ForegroundColor Green "$($values[$answer]) selected"
        Write-Host
    }
    $keys[$answer]
}

function Enter-Value {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $title,
        [Parameter(Mandatory=$false)]
        [string] $description,
        [Parameter(Mandatory=$false)]
        $options,
        [Parameter(Mandatory=$false)]
        [string] $default = "",
        [Parameter(Mandatory=$true)]
        [string] $question,
        [switch] $doNotClearHost = ($host.name -ne "ConsoleHost"),
        [switch] $writeAnswer = ($host.name -ne "ConsoleHost"),
        [switch] $doNotConvertToLower,
        [switch] $previousStep
    )

    if (!$doNotClearHost) {
        Clear-Host
    }

    if ($title) {
        Write-Host -ForegroundColor Yellow $title
        Write-Host
    }
    if ($description) {
        Write-Host $description
        Write-Host
    }
    if ($script:thisStep -lt 100) {
        if (($default) -and !$script:acceptDefaults) {
            Write-Host -ForegroundColor Yellow "!" -NoNewline
            Write-Host " accept default answers for the remaining questions"
        }
        if ($previousStep) {
            Write-Host "Enter " -NoNewline
            Write-Host -ForegroundColor Yellow "x" -NoNewline
            Write-Host " to start over"
            Write-Host "Enter " -NoNewline
            Write-Host -ForegroundColor Yellow "z" -NoNewline
            Write-Host " to go back"
        }
        if (($default) -or ($previousStep)) {
            Write-Host
        }
    }
    $answer = ""
    do {
        Write-Host "$question " -NoNewline
        if ($options) {
            Write-Host "($([string]::Join(', ', $options))) " -NoNewline
        }
        if ($default) {
            Write-Host "(default $default) " -NoNewline
        }
        if ($script:acceptDefaults -and ($default)) {
            $selection = ""
            Write-Host $default
        }
        elseif ($doNotConvertToLower) {
            $selection = Read-Host
        }
        else {
            $selection = (Read-Host).ToLowerInvariant()
        }
        if ($selection -eq "!" -and ($default)) {
            $selection = ""
            $script:acceptDefaults = $true
        }
        if ($selection -eq "") {
            if ($default) {
                $answer = $default
            }
            else {
                Write-Host -ForegroundColor Red "No default value exists. "
            }
        }
        elseif ($selection -eq "x" -and $previousStep) {
            if ($writeAnswer) {
                Write-Host
                Write-Host -ForegroundColor Green "Exit selected"
                Write-Host
            }
            $script:acceptDefaults = $false
            $script:wizardStep = 0
            $script:prevSteps = New-Object System.Collections.Stack
            $script:prevSteps.Push(1)
            return "back"
        }
        elseif ($selection -eq "z" -and $previousStep) {
            if ($writeAnswer) {
                Write-Host
                Write-Host -ForegroundColor Green "Back selected"
                Write-Host
            }
            $script:acceptDefaults = $false
            $script:wizardStep = $script:prevSteps.Pop()
            return "back"
        }
        else {
            if ($options) {
                $answer = $options | Where-Object { $_ -like "$selection*" }
                if (-not ($answer)) {
                    Write-Host -ForegroundColor Red "Illegal answer. Please answer one of the options."
                }
                elseif ($answer -is [Array]) {
                    Write-Host -ForegroundColor Red "Multiple options match the answer. Please answer one of the options that matched the previous selection."
                    $options = $answer
                    $answer = $null
                }
            }
            else {
                $answer = $selection
            }
        }
    } while (-not ($answer))

    if ($writeAnswer) {
        Write-Host
        Write-Host -ForegroundColor Green "$answer selected"
        Write-Host
    }
    $answer
}

function randomchar([string]$str)
{
    $rnd = Get-Random -Maximum $str.length
    [string]$str[$rnd]
}

function Get-RandomPassword {
    $cons = 'bcdfghjklmnpqrstvwxz'
    $voc = 'aeiouy'
    $numbers = '0123456789'

    ((randomchar $cons).ToUpper() + `
     (randomchar $voc) + `
     (randomchar $cons) + `
     (randomchar $voc) + `
     (randomchar $numbers) + `
     (randomchar $numbers) + `
     (randomchar $numbers) + `
     (randomchar $numbers))
}

Clear-Host

$pshost = Get-Host
$pswindow = $pshost.UI.RawUI
$minWidth = 150

if (($pswindow.BufferSize) -and ($pswindow.WindowSize) -and ($pswindow.WindowSize.Width -lt $minWidth)) {
    $buffersize = $pswindow.BufferSize
    $buffersize.width = $minWidth
    $pswindow.buffersize = $buffersize
    
    $newsize = $pswindow.windowsize
    $newsize.width = $minWidth
    $pswindow.windowsize = $newsize
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$randompw = Get-RandomPassword
$bestContainerOsVersion = [System.Version]((Get-BestGenericImageName).Split(':')[1]).Split('-')[0]
$ErrorActionPreference = "STOP"

$script:wizardStep = 0
$script:acceptDefaults = $false

$Step = @{
    "BcContainerHelper"  = 0
    "AcceptEula"         = 1
    "Hosting"            = 2
    "Authentication"     = 3
    "ContainerName"      = 4
    "Version"            = 5
    "SasToken"           = 6
    "Version2"           = 7
    "Country"            = 8
    "TestToolkit"        = 9
    "PerformanceToolkit" = 10
    "PremiumPlan"        = 11
    "CreateTestUsers"    = 12
    "IncludeAL"          = 20
    "ExportAlSource"     = 21
    "IncludeCSIDE"       = 22
    "ExportCAlSource"    = 23
    "Vsix"               = 24
    "License"            = 30
    "Database"           = 31
    "Multitenant"        = 32
    "DNS"                = 35
    "SSL"                = 36
    "Isolation"          = 40
    "Memory"             = 41
    "SaveImage"          = 50
    "Special"            = 60
    "Final"              = 100
}

$script:prevSteps = New-Object System.Collections.Stack
$script:prevSteps.Push(1)

while ($script:wizardStep -le 100) {

$script:thisStep = $script:wizardStep
$script:wizardStep++

switch ($script:thisStep) {
$Step.BcContainerHelper {
    #     ____        _____            _        _                 _    _      _                 
    #    |  _ \      / ____|          | |      (_)               | |  | |    | |                
    #    | |_) | ___| |     ___  _ __ | |_ __ _ _ _ __   ___ _ __| |__| | ___| |_ __   ___ _ __ 
    #    |  _ < / __| |    / _ \| '_ \| __/ _` | | '_ \ / _ \ '__|  __  |/ _ \ | '_ \ / _ \ '__|
    #    | |_) | (__| |____ (_) | | | | |_ (_| | | | | |  __/ |  | |  | |  __/ | |_) |  __/ |   
    #    |____/ \___|\_____\___/|_| |_|\__\__,_|_|_| |_|\___|_|  |_|  |_|\___|_| .__/ \___|_|   
    #                                                                          | |              
    #                                                                          |_|              
    if (!$skipContainerHelperCheck) {
        $module = Get-InstalledModule -Name "BcContainerHelper" -ErrorAction SilentlyContinue
        if (!($module)) {
            $module = Get-Module -Name "BcContainerHelper" -ErrorAction SilentlyContinue
        }
        if (!($module)) {
            Write-Host -ForegroundColor Red "This script has a dependency on the PowerShell module BcContainerHelper."
            Write-Host -ForegroundColor Red "See more here: https://www.powershellgallery.com/packages/bccontainerhelper"
            Write-Host -ForegroundColor Red "Use 'Install-Module BcContainerHelper -force' to install in PowerShell"
            return
        }
        else {
            $myVersion = $module.Version.ToString()
            $prerelease = $myVersion.Contains("-preview")
            if ($prerelease) {
                $latestVersion = (Find-Module -Name bccontainerhelper -AllowPrerelease).Version
                $previewStr = "Prerelease version "
            }
            else {
                $latestVersion = (Find-Module -Name bccontainerhelper).Version
                $previewStr = ""
            }
            if ($latestVersion -eq $myVersion) {
                Write-Host -ForegroundColor Green "You are running BcContainerHelper $previewStr$myVersion (which is the latest version)"
            }
            else {
                Write-Host -ForegroundColor Yellow "You are running BcContainerHelper $previewStr$myVersion. A newer version ($latestVersion) exists, please consider updating."
            }
            Write-Host
        }
    }
}

$Step.AcceptEula {
    
    $acceptEula = Enter-Value `
        -title @'
                             _     ______      _       
     /\                     | |   |  ____|    | |      
    /  \   ___ ___ ___ _ __ | |_  | |__  _   _| | __ _ 
   / /\ \ / __/ __/ _ \ '_ \| __| |  __|| | | | |/ _` |
  / ____ \ (__ (__  __/ |_) | |_  | |____ |_| | | (_| |
 /_/    \_\___\___\___| .__/ \__| |______\__,_|_|\__,_|
                      | |                              
                      |_|                              
'@ `
        -Description "This script will generate a script, which can be used to run Business Central in Docker on your computer.`nYou will be asked a number of questions and the generated script should create a container, which matches your needs.`n`nIn order to run Business Central in Docker, you will need to accept the eula.`nThe supplemental license terms for running Business Central and NAV on Docker can be found here: https://go.microsoft.com/fwlink/?linkid=861843" `
        -options @("Y","N") `
        -question "Please enter Y if you accept the eula"
    if ($acceptEula -ne "Y") {
        Write-Host -ForegroundColor Red "Eula not accepted, aborting..."
        return
    }
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
}

$Step.Hosting {

    $hosting = Select-Value `
        -title @'
  _                     _    _____            _        _                                                             __      ____  __ 
 | |                   | |  / ____|          | |      (_)                                  /\                        \ \    / /  \/  |
 | |     ___   ___ __ _| | | |     ___  _ __ | |_ __ _ _ _ __   ___ _ __    ___  _ __     /  \   _____   _ _ __ ___   \ \  / /| \  / |
 | |    / _ \ / __/ _` | | | |    / _ \| '_ \| __/ _` | | '_ \ / _ \ '__|  / _ \| '__|   / /\ \ |_  / | | | '__/ _ \   \ \/ / | |\/| |
 | |____ (_) | (__ (_| | | | |____ (_) | | | | |_ (_| | | | | |  __/ |    | (_) | |     / ____ \ / /| |_| | | |  __/    \  /  | |  | |
 |______\___/ \___\__,_|_|  \_____\___/|_| |_|\__\__,_|_|_| |_|\___|_|     \___/|_|    /_/    \_\___|\__,_|_|  \___|     \/   |_|  |_|
                                                                                                                                      
'@ `
        -description "Specify where you want to host your Business Central container?`n`nSelecting Local will create a script that needs to run on a computer, which have Docker installed.`nSelecting Azure VM shows a Url with which you can create a VM. This requires an Azure Subscription." `
        -options ([ordered]@{"Local" = "Local docker container"; "AzureVM" = "Docker container in an Azure VM"}) `
        -question "Hosting" `
        -default "Local" `
        -previousStep
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
}

$Step.Authentication {
    if ($hosting -eq "Local") {

        $auth = Select-Value `
            -title @'
                _   _                _   _           _   _             
     /\        | | | |              | | (_)         | | (_)            
    /  \  _   _| |_| |__   ___ _ __ | |_ _  ___ __ _| |_ _  ___  _ __  
   / /\ \| | | | __| '_ \ / _ \ '_ \| __| |/ __/ _` | __| |/ _ \| '_ \ 
  / ____ \ |_| | |_| | | |  __/ | | | |_| | (__ (_| | |_| | (_) | | | |
 /_/    \_\__,_|\__|_| |_|\___|_| |_|\__|_|\___\__,_|\__|_|\___/|_| |_|

'@ `
            -description "Select desired authentication mechanism.`nSelecting predefined credentials means that the script will use hardcoded credentials.`n`nNote: When using Windows authentication, you need to use your Windows Credentials from the host computer and if the computer is domain joined, you will need to be connected to the domain while running the container. You cannot use containers with Windows authentication when offline." `
            -options ([ordered]@{"UserPassword" = "Username/Password authentication"; "Credential" = "Username/Password authentication (admin with predefined password - $predefinedpw)"; "Random" = "Username/Password authentication (admin with random password - $randompw)"; "Windows" = "Windows authentication"}) `
            -question "Authentication" `
            -default "Credential" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
    else {
        $auth = "UserPassword"
    }
}

$Step.ContainerName {
    if ($hosting -eq "Local") {

        $containerName = Enter-Value `
            -title @'
   _____            _        _                   _   _                      
  / ____|          | |      (_)                 | \ | |                     
 | |     ___  _ __ | |_ __ _ _ _ __   ___ _ __  |  \| | __ _ _ __ ___   ___ 
 | |    / _ \| '_ \| __/ _` | | '_ \ / _ \ '__| | . ` |/ _` | '_ ` _ \ / _ \
 | |____ (_) | | | | |_ (_| | | | | |  __/ |    | |\  | (_| | | | | | |  __/
  \_____\___/|_| |_|\__\__,_|_|_| |_|\___|_|    |_| \_|\__,_|_| |_| |_|\___|
                                                                            
'@ `
            -description "Enter the name of the container.`nContainer names are case sensitive and must start with a letter.`n`nNote: We recommend short lower case names as container names." `
            -question "Container name" `
            -default "my" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
    else {
        $containerName = $bcContainerHelperConfig.defaultContainerName
    }
}

$Step.Version {

    if ($hosting -eq "local") { $back = 4 } else { $back = 2 }
    $predef = Select-Value `
        -title @'
 __      __           _             
 \ \    / /          (_)            
  \ \  / /__ _ __ ___ _  ___  _ __  
   \ \/ / _ \ '__/ __| |/ _ \| '_ \ 
    \  /  __/ |  \__ \ | (_) | | | |
     \/ \___|_|  |___/_|\___/|_| |_|

'@ `
        -description "What version of Business Central do you need?`nIf you are developing a Per Tenant Extension for a Business Central Saas tenant, you need a Business Central Sandbox environment" `
        -options ([ordered]@{
            "LatestSandbox" = "Latest Business Central Sandbox"
            "LatestOnPrem" = "Latest Business Central OnPrem"
            "Next Major" = "Insider Business Central Sandbox for Next Major release (requires insider SAS token from http://aka.ms/collaborate)"
            "Next Minor" = "InsiderBusiness Central Sandbox for Next Minor release (requires insider SAS token from http://aka.ms/collaborate)"
            "SpecificSandbox" = "Specific Business Central Sandbox build (requires version number)"
            "SpecificOnPrem" = "Specific Business Central OnPrem build (requires version number)"
            "NAV2018" = "Specific NAV 2018 version"
            "NAV2017" = "Specific NAV 2017 version"
            "NAV2016" = "Specific NAV 2016 version"
        }) `
        -question "Version" `
        -default "LatestSandbox" `
        -writeAnswer `
        -previousStep
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
}

$Step."SasToken" {

    $sasToken = ""
    if ($predef -like "Next*") {
        $sasToken = Enter-Value `
            -title @'
   _____          _____   _______    _              
  / ____|  /\    / ____| |__   __|  | |             
 | (___   /  \  | (___      | | ___ | | _____ _ __  
  \___ \ / /\ \  \___ \     | |/ _ \| |/ / _ \ '_ \ 
  ____) / ____ \ ____) |    | | (_) |   <  __/ | | |
 |_____/_/    \_\_____/     |_|\___/|_|\_\___|_| |_|

'@ `
            -description "Creating container with $predef are released for partners under NDA only.`n`nA SAS (Shared Access Signature) Token is required in order to download insider artifacts.`nA SAS Token can be found on http://aka.ms/collaborate in this document:`nhttps://partner.microsoft.com/en-us/dashboard/collaborate/packages/9387" `
            -question "SAS Token" `
            -previousStep `
            -doNotConvertToLower
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.Version2 {

    $fullVersionNo = $false
    $select = "Latest"
    $storageAccount = "bcartifacts"
    $nav = ""
    if ($predef -like "latest*") {
        $type = $predef.Substring(6)
        $version = ''
    }
    elseif ($predef -like "Next*") {
        $type = "Sandbox"
        $version = ''
        $storageAccount = "bcinsider"
        if ($predef -eq "Next Minor") {
            $select = "SecondToLastMajor"
        }
    }
    elseif ($predef -like "NAV*") {
        $nav = $predef.Substring(3)
        $type = "Onprem"
        $ok = $false
        do {
            $cus = Get-NavArtifactUrl -nav $nav -country 'w1' -select All
            $cu = Enter-Value `
                -description "NAV $nav has $($cus.Count-1) released cumulative updates." `
                -question "Enter CU number (0 is rtm or leave blank for latest)" `
                -default "latest" `
                -doNotClearHost `
                -writeAnswer `
                -previousStep
            
            if ($cu -eq "back") {
                $ok = $true
            }
            else {
                $cuno = $cus.Count-1
                if ($cu -eq "latest" -or ([int]::TryParse($cu, [ref]$cuno) -and ($cuno -ge 0) -and ($cuno -lt $($cus.Count)))) {
                    $ok = $true
                    $version = $cus[$cuno].split('/')[4]
                }
            }
        } while (!$ok)
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
    elseif ($predef -like "specific*") {
        $type = $predef.Substring(8)
        $ok = $false
        do {
            $version = Enter-Value `
                -description "Specify version number.`nIf you specify a full version number (like 15.4.41023.41345), you will get the closest version.`nIf multiple versions matches the entered value, you will be asked to select" `
                -question "Enter version number (format major[.minor[.build[.release]]])" `
                -doNotClearHost `
                -writeAnswer `
                -previousStep
            
            if ($version -eq "back") {
                $ok = $true
            }
            else {
                if ($version.indexOf('.') -eq -1) {
                    $verno = 0
                    $ok = [int32]::TryParse($version, [ref]$verno)
                    if (!$ok) {
                        Write-Host -ForegroundColor Red "Illegal version number"
                    }
                }
                else {
                    $verno = [Version]"0.0.0.0"
                    $ok = [Version]::TryParse($version, [ref]$verno)
                    if (!$ok) {
                        Write-Host -ForegroundColor Red "Illegal version number"
                    }
                    $fullVersionNo = $verno.Revision -ne -1
                }
    
                if ($ok) {

                    if ($fullVersionNo) {
                        $select = "Closest"
                        $artifactUrl = Get-BCArtifactUrl -type $type -version $version -country 'w1' -select 'Closest'
                        if ($artifactUrl) {
                            $foundVersion = $artifactUrl.split('/')[4]
                            if ($foundVersion -ne $version) {
                                Write-Host -ForegroundColor Yellow "The specific version doesn't exist, closest version is $foundVersion"
                            }
                        }
                    }
                    else {
                        $versions = @()
                        Get-BCArtifactUrl -type $type -version $version -country 'w1' -select All | ForEach-Object {
                            $versions += $_.Split('/')[4]
                        }
                        if ($versions.Count -eq 0) {
                            Write-Host -ForegroundColor Red "Unable to find a version matching the specified version"
                            $ok = $false
                        }
                        elseif ($versions.Count -gt 1) {
                            $version = Enter-Value `
                                -options $versions `
                                -question "Select specific version" `
                                -doNotClearHost `
                                -writeAnswer `
                                -previousStep
    
                            if ($version -eq "back") {
                                $ok = $true
                            }
                            else {
                                $fullVersionNo = $true
                            }
                        }
                    }
                }
            }
        } while (!$ok)
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.Country {

    $versionno = $version
    if ($versionno -eq "") {
        $versionno = (Get-BcArtifactUrl -storageAccount $storageAccount -type $type -country "w1" -sasToken $sasToken).split('/')[4]
    }
    $majorVersion = [int]($versionno.Split('.')[0])
    $countries = @()
    Get-BCArtifactUrl -storageAccount $storageAccount -type $type -version $versionno -select All -sasToken $sasToken | ForEach-Object {
        $countries += $_.SubString($_.LastIndexOf('/')+1).Split('?')[0]
    }
    $description = ""
    if ($version -ne "") {
        $description += "Version $version selected`n`n"
    }
    else {
        $description += "Version $versionno identified`n`n"
    }
    if ($type -eq "Sandbox") {
        $default = "us"
        $description += "Please select which country version you want to use.`n`nNote: base is the onprem w1 demodata running in sandbox mode."
    }
    else {
        $default = "w1"
        $description += "Please select which country version you want to use.`n`nNote: NA contains US, CA and MX."
    }

 
    $country = Enter-Value `
        -title @'
   _____                  _              
  / ____|                | |             
 | |     ___  _   _ _ __ | |_ _ __ _   _ 
 | |    / _ \| | | | '_ \| __| '__| | | |
 | |____ (_) | |_| | | | | |_| |  | |_| |
  \_____\___/ \__,_|_| |_|\__|_|   \__, |
                                    __/ |
                                   |___/ 
'@ `
        -description $description `
        -options $countries `
        -default $default `
        -question "Country" `
        -previousStep
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
}

$Step.TestToolkit {

    $testtoolkit = Select-Value `
        -title @'
  _______       _     _______          _ _    _ _   
 |__   __|     | |   |__   __|        | | |  (_) |  
    | | ___ ___| |_     | | ___   ___ | | | ___| |_ 
    | |/ _ \ __| __|    | |/ _ \ / _ \| | |/ / | __|
    | |  __\__ \ |_     | | (_) | (_) | |   <| | |_ 
    |_|\___|___/\__|    |_|\___/ \___/|_|_|\_\_|\__|

'@ `
        -description "Do you need the test toolkit to be installed?`nThe Test Toolkit is needed in order to develop and run tests in the container.`n`nNote: Test Libraries requires a license in order to be used" `
        -options ([ordered]@{"All" = "Full Test Toolkit (Test Framework, Test Libraries and Microsoft tests)"; "Libraries" = "Test Framework and Test Libraries"; "Framework" = "Test Framework"; "No" = "No Test Toolkit needed"}) `
        -question "Test Toolkit" `
        -default "No" `
        -previousStep
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
}

$Step.PerformanceToolkit {

    $performanceToolkit = "N"
    if ($majorVersion -ge 17 -and $testtoolkit -ne "No") {
        $performancetoolkit = Enter-Value `
            -title @'
  _____           __                                            _______          _ _    _ _   
 |  __ \         / _|                                          |__   __|        | | |  (_) |  
 | |__) |__ _ __| |_ ___  _ __ _ __ ___   __ _ _ __   ___ ___     | | ___   ___ | | | ___| |_ 
 |  ___/ _ \ '__|  _/ _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \    | |/ _ \ / _ \| | |/ / | __|
 | |  |  __/ |  | || (_) | |  | | | | | | (_| | | | | (__  __/    | | (_) | (_) | |   <| | |_ 
 |_|   \___|_|  |_| \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|    |_|\___/ \___/|_|_|\_\_|\__|

'@ `
            -description "The Performance Toolkit ships with Business Central 17.0.`n`nDo you need the performance toolkit to be installed?`nThe Performance Toolkit is needed in order to develop and run performance tests in the container." `
            -options @("Y","N") `
            -question "Please enter Y if you want to install the performance toolkit" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.PremiumPlan {
    $assignPremiumPlan = "N"
    if ($type -eq "Sandbox") {
    
        if ($hosting -eq "local") { $back = 8 } else { $back = 7 }
        $assignPremiumPlan = Enter-Value `
            -title @'
  _____                    _                   _____  _             
 |  __ \                  (_)                 |  __ \| |            
 | |__) | __ ___ _ __ ___  _ _   _ _ __ ___   | |__) | | __ _ _ __  
 |  ___/ '__/ _ \ '_ ` _ \| | | | | '_ ` _ \  |  ___/| |/ _` | '_ \ 
 | |   | | |  __/ | | | | | | |_| | | | | | | | |    | | (_| | | | |
 |_|   |_|  \___|_| |_| |_|_|\__,_|_| |_| |_| |_|    |_|\__,_|_| |_|

'@ `
            -Description "When running sandbox, you can select to assign premium plan to the users." `
            -options @("Y","N") `
            -question "Please enter Y if you want to assign premium plan" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$step.IncludeAL {
    $includeAL = "N"
    if ($majorVersion -gt 14) {

        $includeAL = Enter-Value `
            -title @'
           _        ____                                          _____                 _                                  _   
     /\   | |      |  _ \                     /\                 |  __ \               | |                                | |  
    /  \  | |      | |_) | __ _ ___  ___     /  \   _ __  _ __   | |  | | _____   _____| | ___  _ __  _ __ ___   ___ _ __ | |_ 
   / /\ \ | |      |  _ < / _` / __|/ _ \   / /\ \ | '_ \| '_ \  | |  | |/ _ \ \ / / _ \ |/ _ \| '_ \| '_ ` _ \ / _ \ '_ \| __|
  / ____ \| |____  | |_) | (_| \__ \  __/  / ____ \| |_) | |_) | | |__| |  __/\ V /  __/ | (_) | |_) | | | | | |  __/ | | | |_ 
 /_/    \_\______| |____/ \__,_|___/\___| /_/    \_\ .__/| .__/  |_____/ \___| \_/ \___|_|\___/| .__/|_| |_| |_|\___|_| |_|\__|
                                                   | |   | |                                   | |                             
                                                   |_|   |_|                                   |_|                             
'@ `
            -Description "If you are going to perform base app development (modify and publish the base application), you will need to use an option called -includeAL.`n`nThis option is not needed if you are going to write extensions only." `
            -options @("Y","N") `
            -question "Please enter Y if you need to do base app development" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$step.ExportAlSource {
    $exportAlSource = "N"
    if ($includeAL -eq "Y") {
       $exportALSource = Enter-Value `
            -title @'
  ______                       _              _        ____                                        
 |  ____|                     | |       /\   | |      |  _ \                     /\                
 | |__  __  ___ __   ___  _ __| |_     /  \  | |      | |_) | __ _ ___  ___     /  \   _ __  _ __  
 |  __| \ \/ / '_ \ / _ \| '__| __|   / /\ \ | |      |  _ < / _` / __|/ _ \   / /\ \ | '_ \| '_ \ 
 | |____ >  <| |_) | (_) | |  | |_   / ____ \| |____  | |_) | (_| \__ \  __/  / ____ \| |_) | |_) |
 |______/_/\_\ .__/ \___/|_|   \__| /_/    \_\______| |____/ \__,_|___/\___| /_/    \_\ .__/| .__/ 
             | |                                                                      | |   | |    
             |_|                                                                      |_|   |_|    
'@ `
            -Description "When specifying -includeAL, the default behavior is to export the AL source code as a project for you to modify, compile and publish.`nIf you already have a source code repository this is obviously not needed and can be avoided by specifying an option called -doNotExportObjectsToText.`n`nDo you want to export the Base App as an AL source code project?" `
            -options @("Y","N") `
            -question "Please enter Y if you want to export the base app AL source code" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$step.IncludeCSIDE {
    $includeCSIDE = "N"

    if ($majorVersion -le 14) {

        if ($majorVersion -lt 14) {
            $product = "NAV"
        }
        else {
            $product = "a version of Business Central"
        }
        $includeCSIDE = Enter-Value `
            -title @'
   _____     __     _        _____                 _                                  _   
  / ____|   / /\   | |      |  __ \               | |                                | |  
 | |       / /  \  | |      | |  | | _____   _____| | ___  _ __  _ __ ___   ___ _ __ | |_ 
 | |      / / /\ \ | |      | |  | |/ _ \ \ / / _ \ |/ _ \| '_ \| '_ ` _ \ / _ \ '_ \| __|
 | |____ / / ____ \| |____  | |__| |  __/\ V /  __/ | (_) | |_) | | | | | |  __/ | | | |_ 
  \_____/_/_/    \_\______| |_____/ \___| \_/ \___|_|\___/| .__/|_| |_| |_|\___|_| |_|\__|
                                                          | |                             
                                                          |_|                             
'@ `
            -Description "You are running $product, which includes the legacy Windows Client and legacy C/AL development.`nIf you are going to use the Windows Client or use C/AL development, you will need to use an option called -includeCSIDE." `
            -options @("Y","N") `
            -question "Please enter Y if you need CSIDE or Windows Client" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$step.ExportCAlSource {
    $exportCAlSource = "N"
    if ($includeCSIDE -eq "Y") {
       $exportCAlSource = Enter-Value `
            -title @'
  ______                       _      _____     __     _        ____                                        
 |  ____|                     | |    / ____|   / /\   | |      |  _ \                     /\                
 | |__  __  ___ __   ___  _ __| |_  | |       / /  \  | |      | |_) | __ _ ___  ___     /  \   _ __  _ __  
 |  __| \ \/ / '_ \ / _ \| '__| __| | |      / / /\ \ | |      |  _ < / _` / __|/ _ \   / /\ \ | '_ \| '_ \ 
 | |____ >  <| |_) | (_) | |  | |_  | |____ / / ____ \| |____  | |_) | (_| \__ \  __/  / ____ \| |_) | |_) |
 |______/_/\_\ .__/ \___/|_|   \__|  \_____/_/_/    \_\______| |____/ \__,_|___/\___| /_/    \_\ .__/| .__/ 
             | |                                                                               | |   | |    
             |_|                                                                               |_|   |_|    
'@ `
            -Description "When specifying -includeCSIDE, the default behavior is to export the C/AL source code as text files.`nIf you already have a source code repository this is obviously not needed and can be avoided by specifying an option called -doNotExportObjectsToText.`n`nDo you want to export the C/AL base app as text files?" `
            -options @("Y","N") `
            -question "Please enter Y if you want to export the C/AL base app as text files" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.Vsix {

    $vsix = "N"
    if ($majorVersion -gt 14) {
        $vsix = Enter-Value `
            -title @'
           _        _                                                ______      _                 _             
     /\   | |      | |                                              |  ____|    | |               (_)            
    /  \  | |      | |     __ _ _ __   __ _ _   _  __ _  __ _  ___  | |__  __  __ |_ ___ _ __  ___ _  ___  _ __  
   / /\ \ | |      | |    / _` | '_ \ / _` | | | |/ _` |/ _` |/ _ \ |  __| \ \/ / __/ _ \ '_ \/ __| |/ _ \| '_ \ 
  / ____ \| |____  | |____ (_| | | | | (_| | |_| | (_| | (_| |  __/ | |____ >  <| |_  __/ | | \__ \ | (_) | | | |
 /_/    \_\______| |______\__,_|_| |_|\__, |\__,_|\__,_|\__, |\___| |______/_/\_\\__\___|_| |_|___/_|\___/|_| |_|
                                       __/ |             __/ |                                                   
                                      |___/             |___/                                                    
'@ `
            -description "The AL language extension used in the container is normally the vsix file that comes with the version of Business Central selected.`n`nYou can select to use the latest shipped AL Language extension from the marketplace by specifying -vsixFile <url>." `
            -options @("Y","N") `
            -question "Please enter Y if you want to use the latest AL Language extension from the marketplace" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.CreateTestUsers {
    $createTestUsers = "N"
    if ($type -eq "Sandbox") {

        $createTestUsers = Enter-Value `
            -title @'
   _____                _         _______       _     _    _                   
  / ____|              | |       |__   __|     | |   | |  | |                  
 | |     _ __ ___  __ _| |_ ___     | | ___ ___| |_  | |  | |___  ___ _ __ ___ 
 | |    | '__/ _ \/ _` | __/ _ \    | |/ _ \ __| __| | |  | / __|/ _ \ '__/ __|
 | |____| | |  __/ (_| | |_  __/    | |  __\__ \ |_  | |__| \__ \  __/ |  \__ \
  \_____|_|  \___|\__,_|\__\___|    |_|\___|___/\__|  \____/|___/\___|_|  |___/

'@ `
            -Description "When running sandbox, you can select to add test users with special entitlements.`nThe users created are: ExternalAccountant, Premium, Essential, InternalAdmin, TeamMember and DelegatedAdmin.`n`nNote: This requires a license file to be specified." `
            -options @("Y","N") `
            -question "Please enter Y if you want to create test users" `
            -default "N" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.License {

    $licenserequired = ($testtoolkit -ne "No" -or $createTestUsers -eq "Y" -or $exportCAlSource -eq "Y" -or $exportAlSource -eq "Y")
    if ($licenserequired) {
        $description = "Please specify a license file url.`nDue to other selections, you need to specify a license file."
        $default = ""
    }
    else {
        $description = "Please specify a license file url.`nIf you do not specify a license file, you will use the default Cronus Demo License."
        $default = "blank"
    }
    if ($hosting -eq "Local") {
        $description += "`n`nThis can be a local file or a secure direct download url (see https://freddysblog.com/2017/02/26/create-a-secure-url-to-a-file/)"
    }
    else {
        $description += "`n`nThis needs to be a secure direct download url (see https://freddysblog.com/2017/02/26/create-a-secure-url-to-a-file/)"
    }
     
    $licenseFile = Enter-Value `
        -title @'
  _      _                         
 | |    (_)                        
 | |     _  ___ ___ _ __  ___  ___ 
 | |    | |/ __/ _ \ '_ \/ __|/ _ \
 | |____| | (__  __/ | | \__ \  __/
 |______|_|\___\___|_| |_|___/\___|

'@ `
        -description $description `
        -question "License File" `
        -default $default `
        -previousStep
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
    
    if ($licenseFile -eq "blank") {
        $licenseFile = ""
    }
    else {
        $licenseFile = $licenseFile.Trim(@('"'))
    }
}

$Step.Database {
   
    $database = Select-Value `
        -title @'
  _____        _        _                    
 |  __ \      | |      | |                   
 | |  | | __ _| |_ __ _| |__   __ _ ___  ___ 
 | |  | |/ _` | __/ _` | '_ \ / _` / __|/ _ \
 | |__| | (_| | |_ (_| | |_) | (_| \__ \  __/
 |_____/ \__,_|\__\__,_|_.__/ \__,_|___/\___|

'@ `
        -description "When running Business Central on Docker the default behavior is to run the Cronus Demo database inside the container, using the instance of SQLEXPRESS, which is installed there.`nYou can change the database by specifying a database backup or you can configure the container to connect to a database server (which might be on the host)." `
        -options ([ordered]@{"default" = "Use Cronus demo database on SQLEXPRESS inside the container"; "bakfile" = "Restore a database backup on SQLEXPRESS inside the container (must be the correct version)"; "connect" = "Connect to an existing database on a database server (which might be on the host)" }) `
        -question "Database" `
        -default "default" `
        -previousStep
    if ($script:wizardStep -eq $script:thisStep+1) {
        $script:prevSteps.Push($script:thisStep)
    }
    
    if ($database -eq "bakfile") {
        $bakFile = Enter-Value `
            -title "Database Backup" `
            -description "Please specify the full path and filename of the database backup (.bak file) you want to use.`n`nNote: The database backup must be from the same version as the version running in the container" `
            -question "Database Backup" `
            -previousStep
        $bakFile = $bakFile.Trim(@('"'))
    }
    elseif ($database -eq "connect") {
    
        $err = $false
        do {
            $params = @{}
            if ($err) {
                $params = @{ "doNotClearHost" = $true }
            }
            $connectionString = Enter-Value @params `
                -title "Database Connection String" `
                -description "Please enter the connection string for your database connection.`n`nFormat: Server|Data Source=myServerName\myServerInstance;Database|Initial Catalog=myDataBase;User Id=myUsername;Password=myPassword`n`nNote: Specify localhost or . as myServerName if the database server is the host.`nNote: The connection string cannot use integrated security, it must include username and password." `
                -question "Database Connection String" `
                -doNotConvertToLower `
                -previousStep
            if ($connectionString -eq "back") {
                $err = $false
            }
            else {
                $databaseServer = $connectionString.Split(';')   | Where-Object { $_ -like "Server=*" -or $_ -like "Data Source=*" } | % { $_.SubString($_.indexOf('=')+1) }
                $databaseName = $connectionString.Split(';')     | Where-Object { $_ -like "Database=*" -or $_ -like "Initial Catalog=*" } | % { $_.SubString($_.indexOf('=')+1) }
                $databaseUserName = $connectionString.Split(';') | Where-Object { $_ -like "User Id=*" } | % { $_.SubString($_.indexOf('=')+1) }
                $databasePassword = $connectionString.Split(';')   | Where-Object { $_ -like "Password=*" } | % { $_.SubString($_.indexOf('=')+1) }
            
                $err = !(($databaseServer) -and ($databaseName) -and ($databaseUserName) -and ($databasePassword))
                if ($err) {
                    Write-Host -ForegroundColor Red "You need to specify a connection string, which contains all 4 elements described"
                    Write-Host
                }
            }
        } while ($err)
        if ($connectionString -ne "back") {
            $idx = $databaseServer.IndexOf('\')
            if ($idx -ge 0) {
                $databaseInstance = $databaseServer.Substring($idx+1)
                $databaseServer = $databaseServer.Substring(0,$idx)
            }
            else {
                $databaseInstance = ""
            }
            if ($databaseServer -eq "" -or $databaseServer -eq "." -or $databaseServer -eq "localhost") {
                $databaseServer = "host.containerhelper.internal"
            }
            $databaseName = $databaseName.TrimStart('[').TrimEnd(']')
        }
    }
}

$step.Multitenant {
    $multitenant = ""
    if ($database -ne "Connect") {
        if ($type -eq "Sandbox") {
            $description = "You are running a sandbox container, which by default is multitenant.`nBy specifying -multitenant:`$false, you can switch the container to single tenancy."
            $default = "Y"
        }
        else {
            $description = "You are running an onprem container, which by default is singletenant.`nBy specifying -multitenant, you can switch the container to multitenant."
            $default = "N"
        }
        $multitenant = Enter-Value `
            -title @'
  __  __       _ _   _ _                         _   
 |  \/  |     | | | (_) |                       | |  
 | \  / |_   _| | |_ _| |_ ___ _ __   __ _ _ __ | |_ 
 | |\/| | | | | | __| | __/ _ \ '_ \ / _` | '_ \| __|
 | |  | | |_| | | |_| | |_  __/ | | | (_| | | | | |_ 
 |_|  |_|\__,_|_|\__|_|\__\___|_| |_|\__,_|_| |_|\__|

'@ `
            -description $description `
            -options @("Y","N") `
            -question "Please select Y if you want a multitenant container" `
            -default $default `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }

        if ($multitenant -eq $default) {
            $multitenant = ""
        }
    }    
}

$Step.DNS {
    if ($hosting -eq "Local") {

        $options = [ordered]@{"default" = "Use default DNS settings (configured in Docker Daemon)"; "usegoogledns" = "Add Google public dns (8.8.8.8) as DNS to the container" }
        $hostDNS = Get-DnsClientServerAddress | Select-Object –ExpandProperty ServerAddresses | Where-Object { "$_".indexOf(':') -eq -1 } | Select -first 1
        if ($hostDNS) {
            $options += @{ "usehostdns" = "Add your hosts primary DNS server ($hostDNS) as DNS to the container" }
        }
        $dns = Select-Value `
            -title @'
  _____  _   _  _____ 
 |  __ \| \ | |/ ____|
 | |  | |  \| | (___  
 | |  | | . ` |\___ \ 
 | |__| | |\  |____) |
 |_____/|_| \_|_____/ 

'@ `
            -description "On some networks, default DNS resolution does not work inside a running container.`nWhen this is the case, you will see a warning during start saying:`n`nWARNING: DNS resolution not working from within the container.`n`nSome times, this can be fixed by choosing a different DNS server. Some times you have to reconfigure your network or antivirus settings to allow this." `
            -options $options `
            -question "Use DNS" `
            -default "default" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.SSL {
    if ($hosting -eq "Local") {

        $options = [ordered]@{"default" = "Do not use SSL (use http)"; "usessl" = "Use SSL (https) with self-signed certificate"; "usessl2" = "Use SSL (https) with self-signed certificate and install certificate on host computer" }
        $ssl = Select-Value `
            -title @'
   _____ _____ _      
  / ____/ ____| |     
 | (___| (___ | |     
  \___ \\___ \| |     
  ____) |___) | |____ 
 |_____/_____/|______|

'@ `
            -description "If your container is only used from host computer, you likely do not need to setup SSL. There are however functionality (like camera), which requires SSL and will not work if you haven't setup SSL.`nInstalling the self-signed certificate on the host might remove some of the insecure connection warnings from your browser." `
            -options $options `
            -question "Use SSL" `
            -default "default" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.Isolation {
    if ($hosting -eq "Local") {

        $os = (Get-CimInstance Win32_OperatingSystem)
        if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
            throw "Unknown Host Operating System"
        }
    
        $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
        $hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")
    
        try {
            $bestContainerOS = "The image, which matches your host OS best is $($bestContainerOsVersion.ToString())"
            if ($hostOsVersion.Major -eq $bestContainerOsVersion.Major -and $hostOsVersion.Minor -eq $bestContainerOsVersion.Minor -and $hostOsVersion.Build -eq $bestContainerOsVersion.Build) {
                $defaultIsolation = "Process"
            }
            else {
                $defaultIsolation = "Hyper-V"
            }
        }
        catch {
            $bestContainerOsVersion = [System.Version]"0.0.0.0"
            $bestContainerOS = "Unable to determine the image which matches your OS best"
            $defaultIsolation = "Hyper-V"
        }
    
        $description = "Containers can run in process isolation or hyperv isolation, see more here: https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/hyperv-container`nIf not specified, the ContainerHelper will try to detect which isolation mode will work for your OS.`nIf an image with a matching OS is found, Process isolation will be favoured, else Hyper-V will be selected.`n`nYour host OS is Windows $($hostOSVersion.ToString())`n$bestContainerOS`n"

        if ($isAdministrator) {
            $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
            if ($hyperv) {
                $description += "Hyper-V is enabled"
            }
            else {
                $description += "Hyper-V is NOT enabled (you will not be able to use Hyper-V isolation on this host)"
                $defaultIsolation = "Process"
            }
        }
        $options = [ordered]@{"default" = "Allow the ContainerHelper to decide which isolation mode to use (on this host, this will be $defaultIsolation isolation)"; "process" = "Force Process isolation"; "hyperv" = "Force Hyper-V isolation" }
    
        $isolation = Select-Value `
            -title @'
  _____           _       _   _             
 |_   _|         | |     | | (_)            
   | |  ___  ___ | | __ _| |_ _  ___  _ __  
   | | / __|/ _ \| |/ _` | __| |/ _ \| '_ \ 
  _| |_\__ \ (_) | | (_| | |_| | (_) | | | |
 |_____|___/\___/|_|\__,_|\__|_|\___/|_| |_|

'@ `
            -description $description `
            -options $options `
            -question "Isolation" `
            -default "default" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.Memory {
    if ($hosting -eq "Local") {

        $demo = 4
        $development = 8
        if ($majorVersion -ge 16) {
            $newBaseApp = 16
        }
        elseif ($majorVersion -eq 15) {
            $newBaseApp = 12
        }
        else {
            $newBaseApp = 0
        }
    
        $description = "The amount of memory needed by the container depends on what you are going to use it for.`n`nTypical memory consumption for this version of Business Central are:`n- $($demo)G for demo/test usage of Business Central`n- $($demo)G-$($development)G for app development`n"
        if ($newBaseApp) {
            $description += "- $($newBaseApp)G for base app development`n"
        }
        if ($isolation -eq "process" -or ($isolation -eq "default" -and $defaultIsolation -eq "Process")) {
            $description += "`nWhen running Process isolation, the container will only use the actual amount of memory used by the processes running in the container from the host.`nMemory no longer needed by the processes in the container are given back to the host`nYou can set a limit to the amount of memory, the container is allowed to use."
            $defaultDescription = "blank means no limit"
        }
        else {
            $description += "`nWhen running Hyper-V isolation, the container will pre-allocate the full amount of memory given to the container.`n"
            if ($hostOsVersion.Build -ge 17763) {
                $description += "Windows Server 2019 / Windows 10 1809 and later Windows versions are doing this by reserving the memory in the paging file and only using physical memory when needed.`nMemory no longer needed will be freed from physical memory again.`n"
                try {
                    $CompSysResults = Get-CimInstance win32_computersystem -ComputerName $computer -Namespace 'root\cimv2'
                    if ($CompSysResults.AutomaticManagedPagefile) {
                        $description += "Your paging file settings indicate that your paging file is automatically managed, you could consider changing this if you get problems with the size of the paging file.`n"
                    }
                }
                catch {}
            }
            else {
                $description += "Windows Server 2016 and Windows 10 versions before 1809 is doing this by allocating the memory from the main memory pool.`n"
            }
            $defaultDescription = "blank will use ContainerHelper default which is 4G"
        }
    
        $memoryLimit = Enter-Value `
            -title @'
  __  __                                   _      _           _ _   
 |  \/  |                                 | |    (_)         (_) |  
 | \  / | ___ _ __ ___   ___  _ __ _   _  | |     _ _ __ ___  _| |_ 
 | |\/| |/ _ \ '_ ` _ \ / _ \| '__| | | | | |    | | '_ ` _ \| | __|
 | |  | |  __/ | | | | | (_) | |  | |_| | | |____| | | | | | | | |_ 
 |_|  |_|\___|_| |_| |_|\___/|_|   \__, | |______|_|_| |_| |_|_|\__|
                                    __/ |                           
                                   |___/                            
'@ `
            -description $description `
            -question "Specify the amount of memory the container is allowed to use? ($defaultDescription)" `
            -default 'blank' `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    
        if ($memoryLimit -eq "blank") {
            $memoryLimit = ""
        }
        else {
            $memoryLimit = "$($memoryLimit.Trim().ToLowerInvariant().TrimEnd('gb').TrimEnd('g'))G"
        }
    }
}

$Step.SaveImage  {
    if ($hosting -eq "Local") {
        $imageName = Enter-Value `
            -title @'
   _____                   _                            
  / ____|                 (_)                           
 | (___   __ ___   _____   _ _ __ ___   __ _  __ _  ___ 
  \___ \ / _` \ \ / / _ \ | | '_ ` _ \ / _` |/ _` |/ _ \
  ____) | (_| |\ V /  __/ | | | | | | | (_| | (_| |  __/
 |_____/ \__,_| \_/ \___| |_|_| |_| |_|\__,_|\__, |\___|
                                              __/ |     
                                             |___/      
'@ `
            -description "If you are planning on running the same script multiple times, it will save time on subsequent runs to save the image`nThe ContainerHelper will automatically generate an image tag, matching the version number and country of the requested version and on every run it will check whether the image needs to be rebuild.`n`nRecommendation is to use a short name (like mybcimage) if you want to save the image." `
            -question "Image name (or blank to skip saving)" `
            -default "blank" `
            -previousStep
        if ($script:wizardStep -eq $script:thisStep+1) {
            $script:prevSteps.Push($script:thisStep)
        }
    }
}

$Step.Special {
    if ($hosting -eq "Local") {

        # TODO: Publish ports
    
        # TODO: Options like CheckHealth, Restart, Locale, TimeZoneId, Timeout
    
    }
   
}

#  ______ _             _ 
# |  ____(_)           | |
# | |__   _ _ __   __ _| |
# |  __| | | '_ \ / _` | |
# | |    | | | | | (_| | |
# |_|    |_|_| |_|\__,_|_|
#                         
$step.Final {
    $script:acceptDefaults = $false
    if ($hosting -eq "Local") {

        $parameters = @()
        $script = @()
    
        $script += "`$containerName = '$containerName'"
        if ($auth -eq "UserPassword") {
            $script += "`$credential = Get-Credential -Message 'Using UserPassword authentication. Please enter credentials for the container.'"
        }
        elseif ($auth -eq "Windows") {
            $script += "`$credential = Get-Credential -Message 'Using Windows authentication. Please enter your Windows credentials for the host computer.'"
        }
        else
        {
            if ($auth -eq "Credential") {
                $script += "`$password = '$predefinedpw'"
            }
            else {
                $script += "`$password = '$randompw'"
            }
            $script += "`$securePassword = ConvertTo-SecureString -String `$password -AsPlainText -Force"
            $script += "`$credential = New-Object pscredential 'admin', `$securePassword"
            $auth = "UserPassword"
        }
        $parameters += "-credential `$credential"
    
        $script += "`$auth = '$auth'"
        $parameters += "-auth `$auth"

        if ($nav) {
            if ($cu -eq "latest") {
                $script += "`$artifactUrl = Get-NavArtifactUrl -nav '$nav' -country '$country'"
            }
            else {
                $script += "`$artifactUrl = Get-NavArtifactUrl -nav '$nav' -cu '$cu' -country '$country'"
            }
        }
        elseif ($predef -like "Next*") {
            $script += "`$sasToken = '$sasToken'"
            $script += "`$artifactUrl = Get-BcArtifactUrl -storageAccount '$storageAccount' -type '$type' -country '$country' -select '$select' -sasToken `$sasToken"
        }
        else {
            if ($version) {
                $script += "`$artifactUrl = Get-BcArtifactUrl -type '$type' -version '$version' -country '$country' -select '$select'"
            }
            else {
                $script += "`$artifactUrl = Get-BcArtifactUrl -type '$type' -country '$country' -select '$select'"
            }
        }
        $parameters += "-artifactUrl `$artifactUrl"
    
        if ($imageName -ne "blank") {
            $parameters += "-imageName '$($imageName.ToLowerInvariant())'"
        }
    
        if ($database -eq "bakfile") {
            $script += "`$bakFile = '$bakFile'"
            $parameters += "-bakFile `$bakFile"
        }
        elseif ($database -eq "connect") {
            $script += "`$databaseServer = '$databaseServer'"
            $script += "`$databaseInstance = '$databaseInstance'"
            $script += "`$databaseName = '$databaseName'"
            $script += "`$databaseUsername = '$databaseUsername'"
            $script += "`$databasePassword = '$databasePassword'"
            $script += "`$databaseSecurePassword = ConvertTo-SecureString -String `$databasePassword -AsPlainText -Force"
            $script += "`$databaseCredential = New-Object pscredential `$databaseUsername, `$databaseSecurePassword"
            $parameters += "-databaseServer `$databaseServer -databaseInstance `$databaseInstance -databaseName `$databaseName"
            $parameters += "-databaseCredential `$databaseCredential"
        }

        if ($multitenant -eq "Y") {
            $parameters += "-multitenant"
        }
        elseif ($multitenant -eq "N") {
            $parameters += "-multitenant:`$false"
        }
    
        if ($testtoolkit -ne "No") {
            $parameters += "-includeTestToolkit"
            if ($testtoolkit -eq "Framework") {
                $parameters += "-includeTestFrameworkOnly"
            }
            elseif ($testtoolkit -eq "Libraries") {
                $parameters += "-includeTestLibrariesOnly"
            }
            if ($performanceToolkit -eq "Y") {
                $parameters += "-includePerformanceToolkit"
            }
        }
    
        if ($assignPremiumPlan -eq "Y") {
            $parameters += "-assignPremiumPlan"
        }
    
        if ($licenseFile) {
            $script += "`$licenseFile = '$licenseFile'"
            $parameters += "-licenseFile `$licenseFile"
        }
    
        if ($dns -eq "usegoogledns") {
            $parameters += "-dns '8.8.8.8'"
        }
        elseif ($dns -eq "usehostdns") {
            $parameters += "-dns '$hostDNS'"
        }
    
        if ($ssl -eq "usessl") {
            $parameters += "-usessl"
        }
        elseif ($ssl -eq "usessl2") {
            $parameters += "-usessl -installCertificateOnHost"
        }

        if ($isolation -ne "default") {
            $parameters += "-isolation '$isolation'"
        }
        if ($memoryLimit) {
            $parameters += "-memoryLimit $memoryLimit"
        }
        if ($includeAL -eq "Y") {
            if ($exportAlSource -eq "Y") {
                $parameters += "-includeAL"
            }
            else {
                $parameters += "-includeAL -doNotExportObjectsToText"
            }
        }
        if ($includeCSIDE -eq "Y") {
            if ($exportCAlSource -eq "Y") {
                $parameters += "-includeCSIDE"
            }
            else {
                $parameters += "-includeCSIDE -doNotExportObjectsToText"
            }
        }
        if ($vsix -eq "Y") {
            $parameters += "-vsixFile (Get-LatestAlLanguageExtensionUrl)"
        }
    
        $script += "New-BcContainer ``"
        $script += "    -accept_eula ``"
        $script += "    -containerName `$containerName ``"
        $parameters | ForEach-Object { $script += "    $_ ``" }
        $script += "    -updateHosts"
    
        if ($createTestUsers -eq "Y") {
            if ($auth -eq "Windows") {
                $script += "Setup-BcContainerTestUsers -containerName `$containerName -Password `$credential.Password"
            }
            else {
                $script += "Setup-BcContainerTestUsers -containerName `$containerName -Password `$credential.Password -credential `$credential"
            }
        }
    
        $filename = Enter-Value `
            -title @'
  _____                       _____ _          _ _     _____           _       _   
 |  __ \                     / ____| |        | | |   / ____|         (_)     | |  
 | |__) |____      _____ _ __ (___ | |__   ___| | |  | (___   ___ _ __ _ _ __ | |_ 
 |  ___/ _ \ \ /\ / / _ \ '__\___ \| '_ \ / _ \ | |   \___ \ / __| '__| | '_ \| __|
 | |  | (_) \ V  V /  __/ |  ____) | | | |  __/ | |   ____) | (__| |  | | |_) | |_ 
 |_|   \___/ \_/\_/ \___|_| |_____/|_| |_|\___|_|_|  |_____/ \___|_|  |_| .__/ \__|
                                                                        | |        
                                                                        |_|        
'@ `
            -description "The below script will create a container with the requested settings:`n`n$([string]::Join("`n", $script))" `
            -question "Enter filename to save and edit script (or blank to skip saving)" `
            -default "blank"
    
        if ($filename -ne "blank") {
            $filename = $filename.Trim('"')
            if ($filename -notlike "*.ps1") {
                $filename += ".ps1"
            }
            if ($filename.indexOf('\') -eq -1) {
                $filename = Join-Path ([environment]::getfolderpath(“mydocuments”)) $filename
            }
            $script | Out-File $filename
            start -Verb Edit $filename
        }
        else {
            $executeScript = Enter-Value `
                -options @("Y","N") `
                -question "Execute Script" `
                -doNotClearHost
        
            if ($executeScript -eq "Y") {
                Invoke-Expression -Command ([string]::Join("`n", $script))
            }
        }
    }
    else {

        $emailforletsencrypt = Enter-Value `
            -title @'
                               __      ____  __     _____          _   _  __ _           _       
     /\                        \ \    / /  \/  |   / ____|        | | (_)/ _(_)         | |      
    /  \   _____   _ _ __ ___   \ \  / /| \  / |  | |     ___ _ __| |_ _| |_ _  ___ __ _| |_ ___ 
   / /\ \ |_  / | | | '__/ _ \   \ \/ / | |\/| |  | |    / _ \ '__| __| |  _| |/ __/ _` | __/ _ \
  / ____ \ / /| |_| | | |  __/    \  /  | |  | |  | |____  __/ |  | |_| | | | | (__ (_| | |_  __/
 /_/    \_\___|\__,_|_|  \___|     \/   |_|  |_|   \_____\___|_|   \__|_|_| |_|\___\__,_|\__\___|

'@ `
            -description "Your Azure VM can be secured by a Self-Signed Certificate, meaning that you need to install this certificate on any machine connecting to the VM.`nYou can also select to use LetsEncrypt by specifying an email address of the person accepting subscriber agreement for LetsEncrypt (https://letsencrypt.org/repository/).`n`nNote: The LetsEncrypt certificate needs to be renewed after 90 days." `
            -question "Contact EMail for LetsEncrypt (blank to use Self Signed)" `
            -default "blank"
    
        $artifactUrl = [Uri]::EscapeDataString("bcartifacts/$type/$version/$country/$select".ToLowerInvariant())
    
        $url = "http://aka.ms/getbc?accepteula=Yes&artifacturl=$artifactUrl"
        if ($licenseFile) {
            $url += "&licenseFileUri=$([Uri]::EscapeDataString($licenseFile))"
        }
        if ($testToolkit -ne "No") {
            $url += "&TestToolkit=$testToolkit"
        }
        if ($assignPremiumPlan -eq "Y") {
            $url += "&AssignPremiumPlan=Yes"
        }
        if ($createTestUsers -eq "Y") {
            $url += "&CreateTestUsers=Yes"
        }
        if ($emailforletsencrypt -ne "blank") {
            $url += "&contactemailforletsencrypt=$([Uri]::EscapeDataString($emailforletsencrypt))"
        }
    
        $launchUrl = Enter-Value `
            -title @'
                               __      ____  __    _    _ _____  _      
     /\                        \ \    / /  \/  |  | |  | |  __ \| |     
    /  \   _____   _ _ __ ___   \ \  / /| \  / |  | |  | | |__) | |     
   / /\ \ |_  / | | | '__/ _ \   \ \/ / | |\/| |  | |  | |  _  /| |     
  / ____ \ / /| |_| | | |  __/    \  /  | |  | |  | |__| | | \ \| |____ 
 /_/    \_\___|\__,_|_|  \___|     \/   |_|  |_|   \____/|_|  \_\______|
                                                                        
'@ `
            -description "The URL below will launch the Azure Portal with an ARM template, which will create your VM:`n`n$url" `
            -options @("Y","N") `
            -question "Launch Url"
    
        if ($launchUrl -eq "Y") {
            Start-Process $Url
        }
    }
}
}
}