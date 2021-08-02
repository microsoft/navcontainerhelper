<# 
 .Synopsis
  Preview function for Converting BC Apps to Runtime Packages
 .Description
  Preview function for Converting BC Apps to Runtime Packages
 .Parameter skipFailingApps
  If set, a failing app (compiler error or anything else) does not stop the whole process but continues with the next app.
 .Parameter afterEachRuntimeCreation
  A script block to be executed after an app has been converted to a runtime package.
  The parameters are 'appFile', containing the source path and 'runtimeFile' containing the path
  to the newly extracted runtime file or $null if the process has failed and skipFailingApps has been set.
#>
function Convert-BcAppsToRuntimePackages {
    Param(
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $imageName = "my",
        [Parameter(Mandatory=$true)]
        $artifactUrl,
        [Parameter(Mandatory=$false)]
        [string] $licenseFile = "",
        [Parameter(Mandatory=$false)]
        [string] $addinsFolder,
        [Parameter(Mandatory=$false)]
        $publishApps = "",
        [Parameter(Mandatory=$true)]
        $apps,
        [Parameter(Mandatory=$false)]
        $destinationFolder = "",
        [switch] $skipVerification,
        [switch] $skipFailingApps,
        [scriptblock] $afterEachRuntimeCreation = {}
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $appsFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
    try {
        $apps = @(Sort-AppFilesByDependencies -appFiles (CopyAppFilesToFolder -appFiles $apps -folder $appsFolder) -WarningAction SilentlyContinue)
        if ($apps.Count -eq 0) {
            throw "No apps specified"
        }
        if ($publishApps) {
            $publishApps = CopyAppFilesToFolder -appFiles $publishApps -folder $appsFolder
        }
    
        if (!($destinationFolder)) {
            $destinationFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
            New-Item -Path $destinationFolder -ItemType Directory | Out-Null
        }
        elseif (Test-Path $destinationFolder) {
            if (Get-ChildItem -Path $destinationFolder) {
                throw "Destination folder is not empty"
            }
        }
        else {
            New-Item -Path $destinationFolder -ItemType Directory | Out-Null
        }
    
        $password = GetRandomPassword
        $credential= (New-Object pscredential 'admin', (ConvertTo-SecureString -String $password -AsPlainText -Force))

        $additionalParameters = @(
                "--volume ""$($appsFolder):c:\apps"""
                "--volume ""$($destinationFolder):c:\dest"""
                "--env WebClient=N"
                "--env httpSite=N"
             )

        if ($addinsFolder) {
            $additionalParameters += @(
               "--volume ""$($addInsFolder):c:\run\add-ins"""
            )
        }
    
        New-BcContainer `
            -containerName $containerName `
            -imageName $imageName `
            -accept_eula `
            -shortcuts None `
            -artifactUrl $artifactUrl `
            -auth UserPassword `
            -multitenant:$false `
            -Credential $credential `
            -licenseFile $licenseFile `
            -additionalParameters $additionalParameters

        $bcVersion = (Get-BcContainerNavVersion -containerOrImageName $containerName).ToLowerInvariant()
    
        if ($publishApps) {
            $publishApps = Sort-AppFilesByDependencies -containerName $containerName -appFiles $publishApps -WarningAction SilentlyContinue
            $publishApps | % {
                Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($appFile, $skipVerification)
                    Write-Host "Publishing $([System.IO.Path]::GetFileName($appFile))"
                    Publish-NavApp -ServerInstance $serverInstance -path $appFile -skipVerification:$skipVerification -packageType Extension
                } -argumentList (Get-BcContainerPath -containerName $containerName -path $_), $skipVerification
            }
        }
    
        $apps | ForEach-Object {
            $appFile = $_;

            try {
                $afterEachRuntimeCreationParameters = @{ 'appFile' = $appFile; };

                $runtimeFileName = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($appFile, $destinationFolder, $bcVersion, $skipVerification)
                    Write-Host "Publishing $([System.IO.Path]::GetFileName($appFile))";

                    Publish-NavApp -ServerInstance $serverInstance -path $appFile -skipVerification:$skipVerification -packageType Extension;
                    $navAppInfo = Get-NAVAppInfo -Path $appFile;
                    $appPublisher = $navAppInfo.Publisher;
                    $appName = $navAppInfo.Name;
                    $appVersion = $navAppInfo.Version;
                    $appFileName = "$($appPublisher)_$($appName)_$($appVersion).runtime-$($bcVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '';
                    Write-Host "Creating Runtime Package $([System.IO.Path]::GetFileName($appFileName))";
                    Get-NavAppRuntimePackage -ServerInstance $serverInstance -appName $appName -appPublisher $appPublisher -appVersion $appVersion -Path (Join-Path $destinationFolder $appFileName);

                    return $appFileName;
                } -argumentList (Get-BcContainerPath -containerName $containerName -path $appFile), (Get-BcContainerPath -containerName $containerName -path $destinationFolder), $bcVersion, $skipVerification;

                $afterEachRuntimeCreationParameters += @{ 'runtimeFile' = (Join-Path -Path $destinationFolder -ChildPath $runtimeFileName); };
            }
            catch {
                if (!$skipFailingApps.IsPresent)
                {
                    throw;
                }

                Write-Warning -Message "Failed creating Runtime Package for $($appFile).";
                $afterEachRuntimeCreationParameters += @{ 'runtimeFile' = $null; };
            }

            $afterEachRuntimeCreation.Invoke($afterEachRuntimeCreationParameters);
        }
    
        $destinationFolder;
    }
    finally {
        Remove-BcContainer -containerName $containerName
        if (Test-Path $appsFolder) {
            Remove-Item $appsFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
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
Export-ModuleMember -Function Convert-BcAppsToRuntimePackages
