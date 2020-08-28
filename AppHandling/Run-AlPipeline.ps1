<# 
 .Synopsis
  Preview script for running simple AL pipeline
 .Description
  Preview script for running simple AL pipeline
#>
function Run-AlPipeline {
Param(
    [string] $pipelineName,
    [string] $baseFolder,
    [string] $licenseFile,
    [string] $containerName = "$pipelinename-bld".ToLowerInvariant(),
    [string] $imageName = 'my',
    [Boolean] $enableTaskScheduler = $false,
    [string] $memoryLimit = "6G",
    [PSCredential] $credential,
    [string] $codeSignCertPfxFile = "",
    [SecureString] $codeSignCertPfxPassword = $null,
    $installApps = @(),
    $appFolders = @("app", "application"),
    $testFolders = @("test", "testapp"),
    [string] $testResultsFile = "TestResults.xml",
    [string] $packagesFolder = ".packages",
    [string] $outputFolder = ".output",
    [string] $artifact = "bcartifacts/sandbox//us/latest",
    [Boolean] $reuseContainer = $false,
    [switch] $installTestFramework,
    [switch] $installTestLibraries,
    [switch] $azureDevOps,
    [switch] $useDevEndpoint,
    [switch] $doNotRunTests,
    [switch] $keepContainer
)

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

$appFolders  = @($appFolders  | ForEach-Object { if (!$_.contains(':')) { Join-Path $baseFolder $_ } else { $_ } } | Where-Object { Test-Path $_ } )
$testFolders = @($testFolders | ForEach-Object { if (!$_.contains(':')) { Join-Path $baseFolder $_ } else { $_ } } | Where-Object { Test-Path $_ } )
if (!$testResultsFile.Contains(':')) { $testResultsFile = Join-Path $baseFolder $testResultsFile }
if (!$packagesFolder.Contains(':'))  { $packagesFolder  = Join-Path $baseFolder $packagesFolder }
if (!$outputFolder.Contains(':'))    { $outputFolder    = Join-Path $baseFolder $outputFolder }

if (!($appFolders)) {
    throw "No app folders found"
}

$sortedFolders = Sort-AppFoldersByDependencies -appFolders ($appFolders+$testFolders) -WarningAction SilentlyContinue

$segments = "$artifact/////".Split('/')
$artifactUrl = Get-BCArtifactUrl -storageAccount $segments[0] -type $segments[1] -version $segments[2] -country $segments[3] -select $segments[4] -sasToken $env:InsiderSasToken | Select-Object -First 1

if (!($artifactUrl)) {
    throw "Unable to locate artifacts"
}

if ($reuseContainer -and (!($credential))) {
    throw "When using -reuseContainer, you have to specify credentials"
}

Write-Host -ForegroundColor Yellow @'
  _____                               _                
 |  __ \                             | |               
 | |__) |_ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___ 
 |  ___/ _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
 | |  | (_| | | | (_| | | | | | |  __/ |_  __/ |  \__ \
 |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/

'@
Write-Host -NoNewLine -ForegroundColor Yellow "Pipeline name          "; Write-Host $pipelineName
Write-Host -NoNewLine -ForegroundColor Yellow "Container name         "; Write-Host $containerName
Write-Host -NoNewLine -ForegroundColor Yellow "Image name             "; Write-Host $imageName
Write-Host -NoNewLine -ForegroundColor Yellow "ArtifactUrl            "; Write-Host $artifactUrl.Split('?')[0]
Write-Host -NoNewLine -ForegroundColor Yellow "Credential             ";
if ($credential) {
    Write-Host "Specified"
}
else {
    $password = Get-RandomPassword
    Write-Host "admin/$password"
    $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
Write-Host -NoNewLine -ForegroundColor Yellow "MemoryLimit            "; Write-Host $memoryLimit
Write-Host -NoNewLine -ForegroundColor Yellow "Enable Task Scheduler  "; Write-Host $enableTaskScheduler
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Libraries "; Write-Host $installTestLibraries
Write-Host -NoNewLine -ForegroundColor Yellow "Install Test Framework "; Write-Host $installTestFramework
Write-Host -NoNewLine -ForegroundColor Yellow "reuseContainer         "; Write-Host $reuseContainer
Write-Host -NoNewLine -ForegroundColor Yellow "azureDevOps            "; Write-Host $azureDevOps
Write-Host -NoNewLine -ForegroundColor Yellow "License file           "; if ($licenseFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "CodeSignCertPfxFile    "; if ($codeSignCertPfxFile) { Write-Host "Specified" } else { "Not specified" }
Write-Host -NoNewLine -ForegroundColor Yellow "TestResultsFile        "; Write-Host $testResultsFile
Write-Host -NoNewLine -ForegroundColor Yellow "PackagesFolder         "; Write-Host $packagesFolder
Write-Host -NoNewLine -ForegroundColor Yellow "OutputFolder           "; Write-Host $outputFolder
Write-Host -ForegroundColor Yellow "Install Apps"
if ($installApps) { $installApps | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Application folders"
if ($appFolders) { $appFolders | ForEach-Object { Write-Host "- $_" } }  else { Write-Host "- None" }
Write-Host -ForegroundColor Yellow "Test application folders"
if ($testFolders) { $testFolders | ForEach-Object { Write-Host "- $_" } } else { Write-Host "- None" }

$signApps = ($codeSignCertPfxFile -ne "")

Measure-Command {

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

$genericImageName = Get-BestGenericImageName
Write-Host "Pulling $genericImageName"
docker pull $genericImageName

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPulling generic image took $([int]$_.TotalSeconds) seconds" }

$createContainer = $true
if ($reuseContainer -and 
    (Test-BcContainer -containerName $containerName) -and 
    (Get-BcContainerArtifactUrl -containerName $containerName) -eq $artifactUrl -and
    (Get-BcContainerOsVersion -containerOrImageName $containerName) -eq (Get-BcContainerOsVersion -containerOrImageName $genericImageName) -and
    (Get-BcContainerGenericTag -containerOrImageName $containerName) -eq (Get-BcContainerGenericTag -containerOrImageName $genericImageName)) {
        
Write-Host -ForegroundColor Yellow @'
   
  _____                _                               _        _                 
 |  __ \              (_)                             | |      (_)                
 | |__) |___ _   _ ___ _ _ __   __ _    ___ ___  _ __ | |_ __ _ _ _ __   ___ _ __ 
 |  _  // _ \ | | / __| | '_ \ / _` |  / __/ _ \| '_ \| __/ _` | | '_ \ / _ \ '__|
 | | \ \  __/ |_| \__ \ | | | | (_| | | (__ (_) | | | | |_ (_| | | | | |  __/ |   
 |_|  \_\___|\__,_|___/_|_| |_|\__, |  \___\___/|_| |_|\__\__,_|_|_| |_|\___|_|   
                                __/ |                                             
                               |___/                                              
                                                                           
'@

    try {
        Measure-Command {

            Restore-DatabasesInBcContainer `
                -containerName $containerName `
                -bakFolder $pipelineName

            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                $mtstartTime = [DateTime]::Now
                while ([DateTime]::Now.Subtract($mtstartTime).TotalSeconds -le 60) {
                    $tenantInfo = Get-NAVTenant -ServerInstance $ServerInstance -Tenant "default"
                    if ($tenantInfo.State -eq "Operational") { break }
                    Start-Sleep -Seconds 1
                }
                Write-Host "Tenant is $($TenantInfo.State)"
            }

            $createContainer = $false

        } | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRestoring databases took $([int]$_.TotalSeconds) seconds" }
    }
    catch {
        Write-Host -ForegroundColor Red "`nFailed to restore databases, creating new container."
    }

}


if ($createContainer) {

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

    New-BcContainer `
        -accept_eula `
        -containerName $containerName `
        -imageName $imageName `
        -artifactUrl $artifactUrl `
        -Credential $credential `
        -auth UserPassword `
        -updateHosts `
        -licenseFile $licenseFile `
        -EnableTaskScheduler:$enableTaskScheduler `
        -MemoryLimit $memoryLimit `
        -additionalParameters @("--volume $($baseFolder):c:\sources")

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCreating container took $([int]$_.TotalSeconds) seconds" }

if (($installApps) -or $installTestFramework -or $installTestLibraries) {
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

    if ($installTestLibraries) {
        Import-TestToolkitToBcContainer -containerName $containerName -credential $credential -includeTestLibrariesOnly
    }
    elseif ($installTestFramework) {
        Import-TestToolkitToBcContainer -containerName $containerName -credential $credential -includeTestFrameworkOnly
    }

    $installApps | ForEach-Object{
        # Install dependency    
    }

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nInstalling apps took $([int]$_.TotalSeconds) seconds" }
}

if ($reuseContainer) {

Write-Host -ForegroundColor Yellow @'

  ____             _    _                                 _       _        _                        
 |  _ \           | |  (_)                               | |     | |      | |                       
 | |_) | __ _  ___| | ___ _ __   __ _   _   _ _ __     __| | __ _| |_ __ _| |__   __ _ ___  ___ ___ 
 |  _ < / _` |/ __| |/ / | '_ \ / _` | | | | | '_ \   / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \ __|
 | |_) | (_| | (__|   <| | | | | (_| | | |_| | |_) | | (_| | (_| | |_ (_| | |_) | (_| \__ \  __\__ \
 |____/ \__,_|\___|_|\_\_|_| |_|\__, |  \__,_| .__/   \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|___/
                                 __/ |       | |                                                    
                                |___/        |_|                                                    

'@
Measure-Command {

    Backup-BcContainerDatabases `
        -containerName $containerName `
        -bakFolder $pipelineName

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nBacking up databases took $([int]$_.TotalSeconds) seconds" }
}

}

Write-Host -ForegroundColor Yellow @'

   _____                      _ _ _                                     
  / ____|                    (_) (_)                                    
 | |     ___  _ __ ___  _ __  _| |_ _ __   __ _    __ _ _ __  _ __  ___ 
 | |    / _ \| '_ ` _ \| '_ \| | | | '_ \ / _` |  / _` | '_ \| '_ \/ __|
 | |____ (_) | | | | | | |_) | | | | | | | (_| | | (_| | |_) | |_) \__ \
  \_____\___/|_| |_| |_| .__/|_|_|_|_| |_|\__, |  \__,_| .__/| .__/|___/
                       | |                 __/ |       | |   | |        
                       |_|                |___/        |_|   |_|        

'@
Measure-Command {
$apps = @()
$testApps = @()
$sortedFolders | ForEach-Object {
    $folder = $_
    $appFile = Compile-AppInBcContainer `
        -containerName $containerName `
        -credential $credential `
        -appProjectFolder $folder `
        -appOutputFolder $outputFolder `
        -appSymbolsFolder $packagesFolder `
        -CopyAppToSymbolsFolder `
        -AzureDevOps:$azureDevOps
    if ($testFolders.Contains($folder)) {
        $testApps += $appFile
    }
    else {
        $apps += $appFile
    }
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nCompiling apps took $([int]$_.TotalSeconds) seconds" }

if ($signApps -and !$useDevEndpoint) {
Write-Host -ForegroundColor Yellow @'

   _____ _             _                                        
  / ____(_)           (_)                 /\                    
 | (___  _  __ _ _ __  _ _ __   __ _     /  \   _ __  _ __  ___ 
  \___ \| |/ _` | '_ \| | '_ \ / _` |   / /\ \ | '_ \| '_ \/ __|
  ____) | | (_| | | | | | | | | (_| |  / ____ \| |_) | |_) \__ \
 |_____/|_|\__, |_| |_|_|_| |_|\__, | /_/    \_\ .__/| .__/|___/
            __/ |               __/ |          | |   | |        
           |___/               |___/           |_|   |_|        

'@
Measure-Command {
$apps | ForEach-Object {
    $appFile = $_
    Sign-BcContainerApp `
        -containerName $containerName `
        -appFile $appFile `
        -pfxFile $codeSignPfxFile `
        -pfxPassword $codeSignPfxPassword
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nSigning apps took $([int]$_.TotalSeconds) seconds" }
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
$apps+$testApps | ForEach-Object {
    $appFile = $_
    Publish-BcContainerApp `
        -containerName $containerName `
        -credential $credential `
        -appFile $appFile `
        -skipVerification:($testApps.Contains($appFile) -or !$signApps -or $useDevEndpoint) `
        -sync `
        -install `
        -useDevEndpoint:$useDevEndpoint
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nPublishing apps took $([int]$_.TotalSeconds) seconds" }

if (!$doNotRunTests) {
Remove-Item -Path $testResultsFile -Force -ErrorAction SilentlyContinue
if ($testFolders) {
Write-Host -ForegroundColor Yellow @'

  _____                   _               _______       _       
 |  __ \                 (_)             |__   __|     | |      
 | |__) |   _ _ __  _ __  _ _ __   __ _     | | ___ ___| |_ ___ 
 |  _  / | | | '_ \| '_ \| | '_ \ / _` |    | |/ _ \ __| __/ __|
 | | \ \ |_| | | | | | | | | | | | (_| |    | |  __\__ \ |_\__ \
 |_|  \_\__,_|_| |_|_| |_|_|_| |_|\__, |    |_|\___|___/\__|___/
                                   __/ |                        
                                  |___/                         

'@
Measure-Command {
$testFolders | ForEach-Object {
    $appJson = Get-Content -Path (Join-Path $_ "app.json") | ConvertFrom-Json
    Run-TestsInBcContainer `
        -containerName $containerName `
        -credential $credential `
        -extensionId $appJson.id `
        -AzureDevOps "$(if($azureDevOps){'error'}else{'no'})" `
        -XUnitResultFileName $testResultsFile `
        -AppendToXUnitResultFile
}
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRunning tests took $([int]$_.TotalSeconds) seconds" }
}
}

if (!$reuseContainer -and !$keepContainer) {
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
Remove-BcContainer `
    -containerName $containerName
} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nRemoving container took $([int]$_.TotalSeconds) seconds" }
}

} | ForEach-Object { Write-Host -ForegroundColor Yellow "`nAL Pipeline finished in $([int]$_.TotalSeconds) seconds" }

}
Export-ModuleMember -Function Run-AlPipeline

