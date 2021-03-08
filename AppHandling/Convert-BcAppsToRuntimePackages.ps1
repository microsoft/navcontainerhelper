<# 
 .Synopsis
  Preview function for Converting BC Apps to Runtime Packages
 .Description
  Preview function for Converting BC Apps to Runtime Packages
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
        [switch] $skipVerification
    )

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
    
        $apps | % {
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($appFile, $destinationFolder, $bcVersion, $skipVerification)
                Write-Host "Publishing $([System.IO.Path]::GetFileName($appFile))"
                Publish-NavApp -ServerInstance $serverInstance -path $appFile -skipVerification:$skipVerification -packageType Extension
                $navAppInfo = Get-NAVAppInfo -Path $appFile
                $appId = $navAppInfo.AppId
                $appPublisher = $navAppInfo.Publisher
                $appName = $navAppInfo.Name
                $appVersion = $navAppInfo.Version
                $appFileName = "$($appPublisher)_$($appName)_$($appVersion).runtime-$($bcVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
                Write-Host "Creating Runtime Package $([System.IO.Path]::GetFileName($appFileName))"
                Get-NavAppRuntimePackage -ServerInstance $serverInstance -appName $appName -appPublisher $appPublisher -appVersion $appVersion -Path (Join-Path $destinationFolder $appFileName)
            } -argumentList (Get-BcContainerPath -containerName $containerName -path $_), (Get-BcContainerPath -containerName $containerName -path $destinationFolder), $bcVersion, $skipVerification
        }
    
        $destinationFolder
    }
    finally {
        Remove-BcContainer -containerName $containerName
        if (Test-Path $appsFolder) {
            Remove-Item $appsFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
Export-ModuleMember -Function Convert-BcAppsToRuntimePackages