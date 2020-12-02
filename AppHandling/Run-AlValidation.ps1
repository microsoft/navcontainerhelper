<# 
 .Synopsis
  Run AL Validation
 .Description
  Run AL Validation
 .Parameter containerName
  Name of the validation container. Default is bcserver.
 .Parameter imageName
  If imageName is specified it will be used to build an image, which serves as a cache for faster container generation.
  Only speficy imagename if you are going to create multiple containers from the same artifacts.
 .Parameter credential
  These are the credentials used for the container. If not provided, the Run-AlValidation function will generate a random password and use that.
 .Parameter licenseFile
  License file to use for AL Validation
 .Parameter memoryLimit
  MemoryLimit is default set to 8Gb. This is fine for compiling small and medium size apps, but if your have a number of apps or your apps are large and complex, you might need to assign more memory.
 .Parameter installApps
  Array or comma separated list of 3rd party apps to install before validating apps
 .Parameter previousApps
  Array or comma separated list of previous version of apps to use for AppSourceCop validation and upgrade test
 .Parameter apps
  Array or comma separated list of apps to validate
 .Parameter ValidateVersion
  Full or partial version number. If specified, apps will also be validated against this version.
 .Parameter ValidateCurrent
  Include this switch if you want to also validate against current version of Business Central
 .Parameter ValidateNextMinor
  Include this switch if you want to also validate against next minor version of Business Central. If you include this switch you need to specify a sasToken for insider builds as well.
 .Parameter ValidateNextMajor
  Include this switch if you want to also validate against next major version of Business Central. If you include this switch you need to specify a sasToken for insider builds as well.
 .Parameter failOnError
  Include this switch if you want to fail on the first error instead of returning all errors to the caller
 .Parameter sasToken
  Shared Access Service Token for accessing insider artifacts of Business Central. Available on http://aka.ms/collaborate
 .Parameter countries
  Array or comma separated list of country codes to validate against
 .Parameter affixes
  Array or comma separated list of affixes to use for AppSourceCop validation
 .Parameter supportedCountries
  Array or comma separated list of supportedCountries to use for AppSourceCop validation
 .Parameter useLatestAlLanguageExtension
  Include this switch if you want to use the latest AL Extension from marketplace instead of the one included in 
 .Parameter useGenericImage
  Specify a private (or special) generic image to use for the Container OS.
 .Parameter DockerPull
  Override function parameter for docker pull
 .Parameter NewBcContainer
  Override function parameter for New-BcContainer
 .Parameter CompileAppInBcContainer
  Override function parameter for Compile-AppInBcContainer
 .Parameter GetBcContainerAppInfo
  Override function parameter for Get-BcContainerAppInfo
 .Parameter PublishBcContainerApp
  Override function parameter for Publish-BcContainerApp
 .Parameter RemoveBcContainer
  Override function parameter for Remove-BcContainer
#>
function Run-AlValidation {
Param(
    [string] $containerName = "bcserver",
    [string] $imageName = "",
    [PSCredential] $credential,
    [string] $licenseFile,
    [string] $memoryLimit,
    $installApps = @(),
    $previousApps = @(),
    [Parameter(Mandatory=$true)]
    $apps,
    [string] $validateVersion = "",
    [switch] $validateCurrent,
    [switch] $validateNextMinor,
    [switch] $validateNextMajor,
    [switch] $failOnError,
    [string] $sasToken = "",
    [Parameter(Mandatory=$true)]
    $countries,
    $affixes = @(),
    $supportedCountries = @(),
    [switch] $useLatestAlLanguageExtension,
    [switch] $skipVerification,
    [string] $useGenericImage = (Get-BestGenericImageName),
    [scriptblock] $DockerPull,
    [scriptblock] $NewBcContainer,
    [scriptblock] $CompileAppInBcContainer,
    [scriptblock] $PublishBcContainerApp,
    [scriptblock] $GetBcContainerAppInfo,
    [scriptblock] $RemoveBcContainer
)


function RandomChar([string]$str) {
    $rnd = Get-Random -Maximum $str.length
    [string]$str[$rnd]
}

function GetRandomPassword {
    $cons = 'bcdfghjklmnpqrstvwxz'
    $voc = 'aeiouy'
    $numbers = '0123456789'

    ((RandomChar $cons).ToUpper() + `
     (RandomChar $voc) + `
     (RandomChar $cons) + `
     (RandomChar $voc) + `
     (RandomChar $numbers) + `
     (RandomChar $numbers) + `
     (RandomChar $numbers) + `
     (RandomChar $numbers))
}

function DetermineArtifactsToUse {
    Param(
        [string] $version = "",
        [string] $select = "Current",
        [string] $sasToken = "",
        [string[]] $countries = @("us")
    )

Write-Host -ForegroundColor Yellow @'
  _____       _                      _                         _   _  __           _       
 |  __ \     | |                    (_)                       | | (_)/ _|         | |      
 | |  | | ___| |_ ___ _ __ _ __ ___  _ _ __   ___    __ _ _ __| |_ _| |_ __ _  ___| |_ ___ 
 | |  | |/ _ \ __/ _ \ '__| '_ ` _ \| | '_ \ / _ \  / _` | '__| __| |  _/ _` |/ __| __/ __|
 | |__| |  __/ |_  __/ |  | | | | | | | | | |  __/ | (_| | |  | |_| | || (_| | (__| |_\__ \
 |_____/ \___|\__\___|_|  |_| |_| |_|_|_| |_|\___|  \__,_|_|   \__|_|_| \__,_|\___|\__|___/
                                                                                           
'@
    
    $minsto = 'bcartifacts'
    $minsel = $select
    $mintok = $sasToken
    if ($countries) {
        $minver = $null
        $countries | ForEach-Object {
            $url = Get-BCArtifactUrl -version $version -country $_.Trim() -select $select -sasToken $sasToken | Select-Object -First 1
            Write-Host "Found $($url.Split('?')[0])"
            if ($url) {
                $ver = [Version]$url.Split('/')[4]
                if ($minver -eq $null -or $ver -lt $minver) {
                    $minver = $ver
                    $minsto = $url.Split('/')[2].Split('.')[0]
                    $minsel = "Latest"
                    $mintok = $url.Split('?')[1]; if ($mintok) { $mintok = "?$mintok" }
                }
            }
        }
        if ($minver -eq $null) {
            throw "Unable to locate artifacts"
        }
        $version = $minver.ToString()
    }
    $artifactUrl = Get-BCArtifactUrl -storageAccount $minsto -version $version -country $countries[0] -select $minsel -sasToken $mintok | Select-Object -First 1
    if (!($artifactUrl)) {
        throw "Unable to locate artifacts"
    }
    Write-Host "Using $($artifactUrl.Split('?')[0])"
    $artifactUrl
}

$validationResult = @()

if ($memoryLimit -eq "") {
    $memoryLimit = "8G"
}

$assignPremiumPlan = $false
$tenant = "default"

if ($installApps                    -is [String]) { $installApps = @($installApps.Split(',').Trim() | Where-Object { $_ }) }
if ($previousApps                   -is [String]) { $previousApps = @($previousApps.Split(',').Trim() | Where-Object { $_ }) }
if ($apps                           -is [String]) { $apps = @($apps.Split(',').Trim()  | Where-Object { $_ }) }
if ($countries                      -is [String]) { $countries = @($countries.Split(',').Trim() | Where-Object { $_ }) }
if ($affixes                        -is [String]) { $affixes = @($affixes.Split(',').Trim() | Where-Object { $_ }) }
if ($supportedCountries             -is [String]) { $supportedCountries = @($supportedCountries.Split(',').Trim() | Where-Object { $_ }) }

Write-Host -ForegroundColor Yellow @'
  _____                               _                
 |  __ \                             | |               
 | |__) |_ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___ 
 |  ___/ _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
 | |  | (_| | | | (_| | | | | | |  __/ |_  __/ |  \__ \
 |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/

'@
Write-Host -NoNewLine -ForegroundColor Yellow "Container name               "; Write-Host $containerName
Write-Host -NoNewLine -ForegroundColor Yellow "Image name                   "; Write-Host $imageName
Write-Host -NoNewLine -ForegroundColor Yellow "Credential                   ";
if ($credential) {
    Write-Host "Specified"
}
else {
    $password = GetRandomPassword
    Write-Host "admin/$password"
    $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
Write-Host -NoNewLine -ForegroundColor Yellow "License file                 "; if ($licenseFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "MemoryLimit                  "; Write-Host $memoryLimit
Write-Host -NoNewLine -ForegroundColor Yellow "validateVersion              "; Write-Host $validateVersion
Write-Host -NoNewLine -ForegroundColor Yellow "validateCurrent              "; Write-Host $validateCurrent
Write-Host -NoNewLine -ForegroundColor Yellow "validateNextMinor            "; Write-Host $validateNextMinor
Write-Host -NoNewLine -ForegroundColor Yellow "validateNextMajor            "; Write-Host $validateNextMajor
Write-Host -NoNewLine -ForegroundColor Yellow "SasToken                     "; if ($sasToken) { Write-Host "Specified" } else { Write-Host "Not Specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "countries                    "; Write-Host ([string]::Join(',',$countries))
Write-Host -NoNewLine -ForegroundColor Yellow "affixes                      "; Write-Host ([string]::Join(',',$affixes))
Write-Host -NoNewLine -ForegroundColor Yellow "supportedCountries           "; Write-Host ([string]::Join(',',$supportedCountries))
Write-Host -NoNewLine -ForegroundColor Yellow "useLatestAlLanguageExtension "; Write-Host $useLatestAlLanguageExtension

Write-Host -ForegroundColor Yellow "Install Apps"
if ($installApps) { $installApps | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Previous Apps"
if ($previousApps) { $previousApps | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Apps"
if ($apps) { $apps | ForEach-Object { Write-Host "- $_" } }  else { Write-Host "- None" }

if ($DockerPull) {
    Write-Host -ForegroundColor Yellow "DockerPull override"; Write-Host $DockerPull.ToString()
}
else {
    $DockerPull = { Param($imageName) docker pull $imageName }
}
if ($NewBcContainer) {
    Write-Host -ForegroundColor Yellow "NewBccontainer override"; Write-Host $NewBcContainer.ToString()
}
else {
    $NewBcContainer = { Param([Hashtable]$parameters) New-BcContainer @parameters; Invoke-ScriptInBcContainer $parameters.ContainerName -scriptblock { $progressPreference = 'SilentlyContinue' } }
}
if ($PublishBcContainerApp) {
    Write-Host -ForegroundColor Yellow "PublishBcContainerApp override"; Write-Host $PublishBcContainerApp.ToString()
}
else {
    $PublishBcContainerApp = { Param([Hashtable]$parameters) Publish-BcContainerApp @parameters }
}
if ($CompileAppInBcContainer) {
    Write-Host -ForegroundColor Yellow "CompileAppInBcContainer override"; Write-Host $CompileAppInBcContainer.ToString()
}
else {
    $CompileAppInBcContainer = { Param([Hashtable]$parameters) Compile-AppInBcContainer @parameters }
}
if ($GetBcContainerAppInfo) {
    Write-Host -ForegroundColor Yellow "GetBcContainerAppInfo override"; Write-Host $GetBcContainerAppInfo.ToString()
}
else {
    $GetBcContainerAppInfo = { Param([Hashtable]$parameters) Get-BcContainerAppInfo @parameters }
}
if ($RemoveBcContainer) {
    Write-Host -ForegroundColor Yellow "RemoveBcContainer override"; Write-Host $RemoveBcContainer.ToString()
}
else {
    $RemoveBcContainer = { Param([Hashtable]$parameters) Remove-BcContainer @parameters }
}

Measure-Command {

Write-Host -ForegroundColor Yellow @'

  _____       _ _ _                                          _        _                            
 |  __ \     | | (_)                                        (_)      (_)                           
 | |__) |   _| | |_ _ __   __ _    __ _  ___ _ __   ___ _ __ _  ___   _ _ __ ___   __ _  __ _  ___ 
 |  ___/ | | | | | | '_ \ / _` |  / _` |/ _ \ '_ \ / _ \ '__| |/ __| | | '_ ` _ \ / _` |/ _` |/ _ \
 | |   | |_| | | | | | | | (_| | | (_| |  __/ | | |  __/ |  | | (__  | | | | | | | (_| | (_| |  __/
 |_|    \__,_|_|_|_|_| |_|\__, |  \__, |\___|_| |_|\___|_|  |_|\___| |_|_| |_| |_|\__,_|\__, |\___|
                           __/ |   __/ |                                                 __/ |     
                          |___/   |___/                                                 |___/      

'@

Write-Host "Pulling $useGenericImage"

Invoke-Command -ScriptBlock $DockerPull -ArgumentList $useGenericImage
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPulling generic image took $([int]$_.TotalSeconds) seconds" }

Measure-Command {

0..3 | ForEach-Object {

$artifactUrl = ""
if ($_ -eq 0 -and $validateVersion) {
    $artifactUrl = DetermineArtifactsToUse -version $validateVersion -countries $countries -select Latest
}
elseif ($_ -eq 1 -and $validateCurrent) {
    $artifactUrl = DetermineArtifactsToUse -countries $countries -select Current
}
elseif ($_ -eq 2 -and $validateNextMinor) {
    $artifactUrl = DetermineArtifactsToUse -countries $countries -select NextMinor -sasToken $sasToken
}
elseif ($_ -eq 1 -and $validateNextMajor) {
    $artifactUrl = DetermineArtifactsToUse -countries $countries -select NextMajor -sasToken $sasToken
}

if ($artifactUrl) {

$error = $null
$prevProgressPreference = $progressPreference
$progressPreference = 'SilentlyContinue'

try {

$countries | % {
$validateCountry = $_.Trim()

Write-Host -ForegroundColor Yellow @'

   _____                _   _                               _        _                 
  / ____|              | | (_)                             | |      (_)                
 | |     _ __ ___  __ _| |_ _ _ __   __ _    ___ ___  _ __ | |_ __ _ _ _ __   ___ _ __ 
 | |    | '__/ _ \/ _` | __| | '_ \ / _` |  / __/ _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | |____| | |  __/ (_| | |_| | | | | (_| | | (__ (_) | | | | |_ (_| | | | | |  __/ |   
  \_____|_|  \___|\__,_|\__|_|_| |_|\__, |  \___\___/|_| |_|\__\__,_|_|_| |_|\___|_|   
                                     __/ |                                             
                                    |___/                                              

'@

Measure-Command {

    $artifactSegments = $artifactUrl.Split('?')[0].Split('/')
    $artifactUrl = $artifactUrl.Replace("/$($artifactSegments[4])/$($artifactSegments[5])","/$($artifactSegments[4])/$validateCountry")
    Write-Host -ForegroundColor Yellow "Creating container for country $validateCountry"

    $Parameters = @{
        "accept_eula" = $true
        "containerName" = $containerName
        "imageName" = $imageName
        "artifactUrl" = $artifactUrl
        "useGenericImage" = $useGenericImage
        "Credential" = $credential
        "auth" = 'UserPassword'
        "updateHosts" = $true
        "licenseFile" = $licenseFile
        "EnableTaskScheduler" = $true
        "AssignPremiumPlan" = $assignPremiumPlan
        "MemoryLimit" = $memoryLimit
    }
    if ($useLatestAlLanguageExtension) {
        $Parameters += @{
            "vsixFile" = Get-LatestAlLanguageExtensionUrl
        }
    }

    Invoke-Command -ScriptBlock $NewBcContainer -ArgumentList $Parameters

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCreating container took $([int]$_.TotalSeconds) seconds" }

if ($installApps) {
Write-Host -ForegroundColor Yellow @'

  _____           _        _ _ _                                     
 |_   _|         | |      | | (_)                                    
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _    __ _ _ __  _ __  ___ 
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` |  / _` | '_ \| '_ \/ __|
  _| |_| | | \__ \ |_ (_| | | | | | | | (_| | | (_| | |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, |  \__,_| .__/| .__/|___/
                                        __/ |       | |   | |        
                                       |___/        |_|   |_|        

'@
Measure-Command {

    $installApps | ForEach-Object{
        $Parameters = @{
            "containerName" = $containerName
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $_
            "skipVerification" = $skipVerification
            "sync" = $true
            "install" = $true
        }
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
}

Write-Host -ForegroundColor Yellow @'
  _____                   _                                    _____                           _____            
 |  __ \                 (_)                 /\               / ____|                         / ____|           
 | |__) |   _ _ __  _ __  _ _ __   __ _     /  \   _ __  _ __| (___   ___  _   _ _ __ ___ ___| |     ___  _ __  
 |  _  / | | | '_ \| '_ \| | '_ \ / _` |   / /\ \ | '_ \| '_ \\___ \ / _ \| | | | '__/ __/ _ \ |    / _ \| '_ \ 
 | | \ \ |_| | | | | | | | | | | | (_| |  / ____ \| |_) | |_) |___) | (_) | |_| | | | (__  __/ |____ (_) | |_) |
 |_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, | /_/    \_\ .__/| .__/_____/ \___/ \__,_|_|  \___\___|\_____\___/| .__/ 
                                   __/ |          | |   | |                                              | |    
                                  |___/           |_|   |_|                                              |_|    
'@

$validationResult += @(Run-AlCops `
    -containerName $containerName `
    -credential $credential `
    -previousApps $previousApps `
    -apps $apps `
    -affixes $affixes `
    -supportedCountries $supportedCountries `
    -enableAppSourceCop `
    -failOnError:$failOnError)

if ($previousApps) {
Write-Host -ForegroundColor Yellow @'

  _____           _        _ _ _               _____                _                                            
 |_   _|         | |      | | (_)             |  __ \              (_)                     /\                    
   | |  _ __  ___| |_ __ _| | |_ _ __   __ _  | |__) | __ _____   ___  ___  _   _ ___     /  \   _ __  _ __  ___ 
   | | | '_ \/ __| __/ _` | | | | '_ \ / _` | |  ___/ '__/ _ \ \ / / |/ _ \| | | / __|   / /\ \ | '_ \| '_ \/ __|
  _| |_| | | \__ \ |_ (_| | | | | | | | (_| | | |   | | |  __/\ V /| | (_) | |_| \__ \  / ____ \| |_) | |_) \__ \
 |_____|_| |_|___/\__\__,_|_|_|_|_| |_|\__, | |_|   |_|  \___| \_/ |_|\___/ \__,_|___/ /_/    \_\ .__/| .__/|___/
                                        __/ |                                                   | |   | |        
                                       |___/                                                    |_|   |_|        

'@
Measure-Command {
    $previousApps | ForEach-Object{
        $Parameters = @{
            "containerName" = $containerName
            "tenant" = $tenant
            "credential" = $credential
            "appFile" = $_
            "skipVerification" = $skipVerification
            "sync" = $true
            "install" = $true
            "useDevEndpoint" = $false
        }
        Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
}

Write-Host -ForegroundColor Yellow @'

  _____       _     _ _     _     _                                        
 |  __ \     | |   | (_)   | |   (_)                 /\                    
 | |__) |   _| |__ | |_ ___| |__  _ _ __   __ _     /  \   _ __  _ __  ___ 
 |  ___/ | | | '_ \| | / __| '_ \| | '_ \ / _` |   / /\ \ | '_ \| '_ \/ __|
 | |   | |_| | |_) | | \__ \ | | | | | | | (_| |  / ____ \| |_) | |_) \__ \
 |_|    \__,_|_.__/|_|_|___/_| |_|_|_| |_|\__, | /_/    \_\ .__/| .__/|___/
                                           __/ |          | |   | |        
                                          |___/           |_|   |_|        

'@
Measure-Command {

$installedApps = Invoke-Command -ScriptBlock $GetBcContainerAppInfo -ArgumentList $Parameters

$apps | ForEach-Object {
    
    $tmpFolder = Join-Path $ENV:TEMP ([Guid]::NewGuid().ToString())
    Extract-AppFileToFolder -appFilename $_ -appFolder $tmpFolder -generateAppJson
    $appJsonFile = Join-Path $tmpfolder "app.json"
    $appJson = Get-Content $appJsonFile | ConvertFrom-Json
    Remove-Item $tmpFolder -Recurse -Force

    $installedApp = $false
    if ($installedApps | Where-Object { $_.Name -eq $appJson.Name -and $_.Publisher -eq $appJson.Publisher -and $_.AppId -eq $appJson.Id }) {
        $installedApp = $true
    }

    $Parameters = @{
        "containerName" = $containerName
        "tenant" = $tenant
        "credential" = $credential
        "appFile" = $_
        "skipVerification" = $skipVerification
        "sync" = $true
        "install" = !$installedApp
        "upgrade" = $installedApp
    }

    Invoke-Command -ScriptBlock $PublishBcContainerApp -ArgumentList $Parameters

}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPublishing apps took $([int]$_.TotalSeconds) seconds" }
}

} catch {
    $error = $_
}
finally {
    $progressPreference = $prevProgressPreference
}

Write-Host -ForegroundColor Yellow @'

  _____                           _                _____            _        _                 
 |  __ \                         (_)              / ____|          | |      (_)                
 | |__) |___ _ __ ___   _____   ___ _ __   __ _  | |     ___  _ __ | |_ __ _ _ _ __   ___ _ __ 
 |  _  // _ \ '_ ` _ \ / _ \ \ / / | '_ \ / _` | | |    / _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | | \ \  __/ | | | | | (_) \ V /| | | | | (_| | | |____ (_) | | | | |_ (_| | | | | |  __/ |   
 |_|  \_\___|_| |_| |_|\___/ \_/ |_|_| |_|\__, |  \_____\___/|_| |_|\__\__,_|_|_| |_|\___|_|   
                                           __/ |                                               
                                          |___/                                                

'@
Measure-Command {

    $Parameters = @{
        "containerName" = $containerName
    }
    Invoke-Command -ScriptBlock $RemoveBcContainer -ArgumentList $Parameters
   
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRemoving container took $([int]$_.TotalSeconds) seconds" }

if ($error) {
    throw $error
}

}

}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nAL Validation finished in $([int]$_.TotalSeconds) seconds" }

$validationResult

}
Export-ModuleMember -Function Run-AlValidation
