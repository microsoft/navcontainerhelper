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
 .Parameter includeWarnings
  Include this switch if you want to include Warnings
 .Parameter doNotIgnoreInfos
  Include this switch if you don't want to ignore Infos (if you want to include Infos)
 .Parameter sasToken
  Shared Access Service Token for accessing insider artifacts of Business Central. Available on http://aka.ms/collaborate
 .Parameter countries
  Array or comma separated list of country codes to validate against
 .Parameter affixes
  Array or comma separated list of affixes to use for AppSourceCop validation
 .Parameter supportedCountries
  Array or comma separated list of supportedCountries to use for AppSourceCop validation
 .Parameter vsixFile
  Specify a URL or path to a .vsix file in order to override the .vsix file in the image with this.
  Use Get-LatestAlLanguageExtensionUrl to get latest AL Language extension from Marketplace.
  Use Get-AlLanguageExtensionFromArtifacts -artifactUrl (Get-BCArtifactUrl -select NextMajor -sasToken $insiderSasToken) to get latest insider .vsix
  Use . to specify that you want to use the AL Language extension from the container spun up for validation
  Default is to use the latest AL Language extension from Marketplace for non-insider containers and the Language extension in the container for insider containers
 .Parameter skipVerification
  Include this parameter to skip verification of code signing certificate. Note that you cannot request Microsoft to set this parameter when validating for AppSource.
 .Parameter skipUpgrade
  Include this parameter to skip upgrade. You can request Microsoft to set this when your previous app cannot install on the version we are validating for.
 .Parameter skipAppSourceCop
  Include this parameter to skip appSourceCop. You cannot request Microsoft to set this when running validation
 .Parameter skipConnectionTest
  Include this parameter to skip the connection test. If Connection Test fails in validation, Microsoft will execute manual validation.
 .Parameter throwOnError
  Include this switch if you want Run-AlValidation to throw an error with the validation results instead of returning them to the caller
 .Parameter useGenericImage
  Specify a private (or special) generic image to use for the Container OS.
 .Parameter multitenant
  Include this parameter to use a multitenant container for the validation tests. Default is to use single tenant as validation doesn't run tests.
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
    [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
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
    [switch] $includeWarnings,
    [switch] $doNotIgnoreInfos,
    [string] $sasToken = "",
    [Parameter(Mandatory=$true)]
    $countries,
    $affixes = @(),
    $supportedCountries = @(),
    [string] $vsixFile = "",
    [switch] $skipVerification,
    [switch] $skipUpgrade,
    [switch] $skipAppSourceCop,
    [switch] $skipConnectionTest = $true,
    [switch] $throwOnError,
    [string] $useGenericImage = "",
    [switch] $multitenant,
    [scriptblock] $DockerPull,
    [scriptblock] $NewBcContainer,
    [scriptblock] $CompileAppInBcContainer,
    [scriptblock] $PublishBcContainerApp,
    [scriptblock] $GetBcContainerAppInfo,
    [scriptblock] $RemoveBcContainer
)

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
            $url = Get-BCArtifactUrl -version $version -country $_ -select $select -sasToken $sasToken | Select-Object -First 1
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

function GetApplicationDependency( [string] $appFile, [string] $minVersion = "0.0" ) {
    $tmpFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
    try {
        Extract-AppFileToFolder -appFilename $appFile -appFolder $tmpFolder -generateAppJson
        $appJsonFile = Join-Path $tmpFolder "app.json"
        $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
    }
    catch {
        throw "Cannot unpack app $([System.IO.Path]::GetFileName($appFile)), it might be a runtime package."
    }
    finally {
        if (Test-Path $tmpFolder) {
            Remove-Item $tmpFolder -Recurse -Force
        }
    }
    if ($appJson.PSObject.Properties.Name -eq "Application") {
        $version = $appJson.application
    }
    else {
        $version = $appJson.dependencies | Where-Object { $_.Name -eq "Base Application" -and $_.Publisher -eq "Microsoft" } | % { $_.Version }
        if (!$version) {
            $version = $minVersion
        }
    }
    if ([System.Version]$version -lt [System.Version]$minVersion) {
        $version = $minVersion
    }
    $version
}

function GetFilePath( [string] $path ) {
    if ($path -like "http://*" -or $path -like "https://*") {
        return $path
    }
    if (!(Test-Path $path -PathType Leaf)) {
        throw "Unable to locate app file: $path"
    }
    else {
        return (Get-Item -Path $path).FullName
    }
}

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

'GetBcContainerAppInfo','PublishBcContainerApp','multitenant','SkipConnectionTest','skipUpgrade','SkipVerification','ImageName' | % {
    if ($PSBoundParameters.Keys.Contains($_)) {
        Write-Host -ForegroundColor Red "WARNING: Parameter $_ is no longer used in Run-AlValidation, please remove the parameter"
    }
}

if ($useGenericImage -eq "") {
    $useGenericImage = Get-BestGenericImageName -filesOnly
}

$warningsToShow = @()
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

$installApps = @($installApps | ForEach-Object { GetFilePath $_ })
$previousApps = @($previousApps | ForEach-Object { GetFilePath $_ })
$apps = @($apps | ForEach-Object { GetFilePath $_ })

$countries = @($countries | Where-Object { $_ } | ForEach-Object { getCountryCode -countryCode $_ })
$validateCountries = @($countries | ForEach-Object {
    $countryCode = $_
    if ($bcContainerHelperConfig.mapCountryCode.PSObject.Properties.Name -eq $countryCode) { 
        $bcContainerHelperConfig.mapCountryCode."$countryCode"
    }
    else {
        $countryCode
    }
} | Select-Object -Unique)
$supportedCountries = @($supportedCountries | Where-Object { $_ } | ForEach-Object { getCountryCode -countryCode $_ })

$latestAlLanguageUrl = Get-LatestAlLanguageExtensionUrl

Write-Host -ForegroundColor Yellow @'
  _____                               _                
 |  __ \                             | |               
 | |__) |_ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___ 
 |  ___/ _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
 | |  | (_| | | | (_| | | | | | |  __/ |_  __/ |  \__ \
 |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/

'@
Write-Host -NoNewLine -ForegroundColor Yellow "Container name               "; Write-Host $containerName
Write-Host -NoNewLine -ForegroundColor Yellow "Credential                   ";
if ($credential) {
    Write-Host "Specified"
}
else {
    $password = GetRandomPassword
    Write-Host "admin/$password"
    $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
Write-Host -NoNewLine -ForegroundColor Yellow "MemoryLimit                  "; Write-Host $memoryLimit
Write-Host -NoNewLine -ForegroundColor Yellow "validateVersion              "; Write-Host $validateVersion
Write-Host -NoNewLine -ForegroundColor Yellow "validateCurrent              "; Write-Host $validateCurrent
Write-Host -NoNewLine -ForegroundColor Yellow "validateNextMinor            "; Write-Host $validateNextMinor
Write-Host -NoNewLine -ForegroundColor Yellow "validateNextMajor            "; Write-Host $validateNextMajor
Write-Host -NoNewLine -ForegroundColor Yellow "SasToken                     "; if ($sasToken) { Write-Host "Specified" } else { Write-Host "Not Specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "countries                    "; Write-Host ([string]::Join(',',$countries))
Write-Host -NoNewLine -ForegroundColor Yellow "validateCountries            "; Write-Host ([string]::Join(',',$validateCountries))
Write-Host -NoNewLine -ForegroundColor Yellow "affixes                      "; Write-Host ([string]::Join(',',$affixes))
Write-Host -NoNewLine -ForegroundColor Yellow "supportedCountries           "; Write-Host ([string]::Join(',',$supportedCountries))
Write-Host -NoNewLine -ForegroundColor Yellow "vsixFile                     "; Write-Host $vsixFile

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
if ($CompileAppInBcContainer) {
    Write-Host -ForegroundColor Yellow "CompileAppInBcContainer override"; Write-Host $CompileAppInBcContainer.ToString()
}
if ($RemoveBcContainer) {
    Write-Host -ForegroundColor Yellow "RemoveBcContainer override"; Write-Host $RemoveBcContainer.ToString()
}
else {
    $RemoveBcContainer = { Param([Hashtable]$parameters) Remove-BcContainer @parameters }
}

$currentArtifactUrl = ""

if ("$validateVersion" -eq "" -and !$validateCurrent -and !$validateNextMinor -and !$validateNextMajor) {
$currentArtifactUrl = DetermineArtifactsToUse -countries $validateCountries -select Current
Write-Host -ForegroundColor Yellow @'
  _____       _                      _       _                   _                           _                       
 |  __ \     | |                    (_)     (_)                 | |                         | |                      
 | |  | | ___| |_ ___ _ __ _ __ ___  _ _ __  _ _ __   __ _    __| | ___ _ __   ___ _ __   __| | ___ _ __   ___ _   _ 
 | |  | |/ _ \ __/ _ \ '__| '_ ` _ \| | '_ \| | '_ \ / _` |  / _` |/ _ \ '_ \ / _ \ '_ \ / _` |/ _ \ '_ \ / __| | | |
 | |__| |  __/ |_  __/ |  | | | | | | | | | | | | | | (_| | | (_| |  __/ |_) |  __/ | | | (_| |  __/ | | | (__| |_| |
 |_____/ \___|\__\___|_|  |_| |_| |_|_|_| |_|_|_| |_|\__, |  \__,_|\___| .__/ \___|_| |_|\__,_|\___|_| |_|\___|\__, |
                                                      __/ |            | |                                      __/ |
                                                     |___/             |_|                                     |___/ 
'@

$validateCurrent = $true
$version = [System.Version]::new($currentArtifactUrl.Split('/')[4])
$currentVersion = "$($version.Major).$($version.Minor)"
$validateVersion = "17.0"

$tmpAppsFolder = Join-Path $hosthelperfolder ([Guid]::NewGuid().ToString())
@(CopyAppFilesToFolder -appFiles @($installApps+$apps) -folder $tmpAppsFolder) | % {
    $appFile = $_
    $version = GetApplicationDependency -appFile $appFile -minVersion $validateVersion
    if ([System.Version]$version -gt [System.Version]$validateVersion) {
        $version = [System.Version]::new($version)
        $validateVersion = "$($version.Major).$($version.Minor)"
    }
}
Remove-Item -Path $tmpAppsFolder -Recurse -Force
Write-Host "Validating against Current Version ($currentVersion)"
if ($validateVersion -eq $currentVersion) {
    $validateVersion = ""
}
else {
    Write-Host "Additionally validating against application dependency ($validateVersion)"
}
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
if ($_ -eq 0 -and $validateCurrent) {
    if ($currentArtifactUrl -eq "") {
        $currentArtifactUrl = DetermineArtifactsToUse -countries $validateCountries -select Current
    }
    $artifactUrl = $currentArtifactUrl
}
elseif ($_ -eq 1 -and $validateVersion) {
    $artifactUrl = DetermineArtifactsToUse -version $validateVersion -countries $validateCountries -select Latest
}
elseif ($_ -eq 2 -and $validateNextMinor) {
    $artifactUrl = DetermineArtifactsToUse -countries $validateCountries -select NextMinor -sasToken $sasToken
}
elseif ($_ -eq 1 -and $validateNextMajor) {
    $artifactUrl = DetermineArtifactsToUse -countries $validateCountries -select NextMajor -sasToken $sasToken
}

if ($artifactUrl) {

$prevProgressPreference = $progressPreference
$progressPreference = 'SilentlyContinue'

$appPackagesFolder = Join-Path $hosthelperfolder ([Guid]::NewGuid().ToString())
New-Item $appPackagesFolder -ItemType Directory | Out-Null

try {

$validateCountries | % {
$validateCountry = $_

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

    if ($vsixFile -eq ".") {
        $useVsix = ""
    }
    elseif ($vsixFile -eq "") {
        if (($artifactSegments[2] -like "bcinsider.*") -or ($artifactSegments[2] -like "bcpublicpreview.*")) {
            $useVsix = ""
        }
        else {
            $useVsix = $latestAlLanguageUrl
        }
    }
    else {
        $useVsix = $vsixFile
    }

    $Parameters = @{
        "accept_eula" = $true
        "containerName" = $containerName
        "artifactUrl" = $artifactUrl
        "useGenericImage" = $useGenericImage
        "Credential" = $credential
        "auth" = 'UserPassword'
        "updateHosts" = $true
        "vsixFile" = $useVsix
        "EnableTaskScheduler" = $true
        "AssignPremiumPlan" = $assignPremiumPlan
        "MemoryLimit" = $memoryLimit
        "FilesOnly" = $true
    }

    Invoke-Command -ScriptBlock $NewBcContainer -ArgumentList $Parameters

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCreating container took $([int]$_.TotalSeconds) seconds" }

if ($installApps) {
    CopyAppFilesToFolder -appFiles $installApps -folder $appPackagesFolder | Out-Null
}

if (!$skipAppSourceCop) {
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
Measure-Command {
$parameters = @{
    "containerName" = $containerName
    "credential" = $credential
    "previousApps" = @($previousApps)
    "apps" = @($apps)
    "affixes" = $affixes
    "supportedCountries" = $supportedCountries
    "enableAppSourceCop" = $true
    "failOnError" = $failOnError
    "ignoreWarnings" = !$includeWarnings
    "doNotIgnoreInfos" = !$doNotIgnoreInfos
    "appPackagesFolder" = $appPackagesFolder
}
if ($CompileAppInBcContainer) {
    $parameters += @{
        "CompileAppInBcContainer" = $CompileAppInBcContainer
    }
}
$validationResult += @(Run-AlCops @Parameters)

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRunning AppSourceCop took $([int]$_.TotalSeconds) seconds" }

}

}

} catch {
    $error = "Unexpected error while validating app. Error is: $($_.Exception.Message)"
    $validationResult += $error
    Write-Host -ForegroundColor Red $error
    Write-Host -ForegroundColor Red $_.ScriptStackTrace

}
finally {
    $progressPreference = $prevProgressPreference
    Remove-Item -Path $appPackagesFolder -Recurse -Force
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

}

}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nAL Validation finished in $([int]$_.TotalSeconds) seconds" }

if ($validationResult) {

Write-Host -ForegroundColor Red @'
 __      __   _ _     _       _   _               _____                _ _       
 \ \    / /  | (_)   | |     | | (_)             |  __ \              | | |      
  \ \  / /_ _| |_  __| | __ _| |_ _  ___  _ __   | |__) |___ ___ _   _| | |_ ___ 
   \ \/ / _` | | |/ _` |/ _` | __| |/ _ \| '_ \  |  _  // _ \ __| | | | | __/ __|
    \  / (_| | | | (_| | (_| | |_| | (_) | | | | | | \ \  __\__ \ |_| | | |_\__ \
     \/ \__,_|_|_|\__,_|\__,_|\__|_|\___/|_| |_| |_|  \_\___|___/\__,_|_|\__|___/

'@
$validationResult | Write-Host -ForegroundColor Red
Write-Host -ForegroundColor Red @'
  _____                          ___      __   _ _     _       _   _               ______    _ _                
 |  __ \                   /\   | \ \    / /  | (_)   | |     | | (_)             |  ____|  (_) |               
 | |__) |   _ _ __ ______ /  \  | |\ \  / /_ _| |_  __| | __ _| |_ _  ___  _ __   | |__ __ _ _| |_   _ _ __ ___ 
 |  _  / | | | '_ \______/ /\ \ | | \ \/ / _` | | |/ _` |/ _` | __| |/ _ \| '_ \  |  __/ _` | | | | | | '__/ _ \
 | | \ \ |_| | | | |    / ____ \| |  \  / (_| | | | (_| | (_| | |_| | (_) | | | | | | | (_| | | | |_| | | |  __/
 |_|  \_\__,_|_| |_|   /_/    \_\_|   \/ \__,_|_|_|\__,_|\__,_|\__|_|\___/|_| |_| |_|  \__,_|_|_|\__,_|_|  \___|

'@

AddTelemetryProperty -telemetryScope $telemetryScope -key "Validation" -value "Failure"
AddTelemetryProperty -telemetryScope $telemetryScope -key "Result" -value ($validationResult -join "`n")
if ($throwOnError) {
    throw ($validationResult -join "`n")
}
else {
    $validationResult
}

}
else {
Write-Host -ForegroundColor Green @'
  _____                          ___      __   _ _     _       _   _                _____                            
 |  __ \                   /\   | \ \    / /  | (_)   | |     | | (_)              / ____|                           
 | |__) |   _ _ __ ______ /  \  | |\ \  / /_ _| |_  __| | __ _| |_ _  ___  _ __   | (___  _   _  ___ ___ ___ ___ ___ 
 |  _  / | | | '_ \______/ /\ \ | | \ \/ / _` | | |/ _` |/ _` | __| |/ _ \| '_ \   \___ \| | | |/ __/ __/ _ \ __/ __|
 | | \ \ |_| | | | |    / ____ \| |  \  / (_| | | | (_| | (_| | |_| | (_) | | | |  ____) | |_| | (__ (__  __\__ \__ \
 |_|  \_\__,_|_| |_|   /_/    \_\_|   \/ \__,_|_|_|\__,_|\__,_|\__|_|\___/|_| |_| |_____/ \__,_|\___\___\___|___/___/
                                                                                                  
'@

AddTelemetryProperty -telemetryScope $telemetryScope -key "Validation" -value "Success"
}

if ($warningsToShow) {
    ($warningsToShow -join "`n") | Write-Host -ForegroundColor Yellow
}
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Run-AlValidation
