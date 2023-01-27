<#
 .Synopsis
  Uploads, Imports and Applys a configuration package into a tenant in a NAV/BC Container
 .Description
  Using Management APIs, this function uploads, imports and applys a configuration package into a tenant in a NAV/BC Container
  Note that the TaskScheduler should be enabled when using this function.
  The function will display a warning if the Task Scheduler is not running.
 .Parameter containerName
  Name of the container in which you want to apply the configuration package to
 .Parameter tenant
  Name of the tenant in which the configuration package should be applied
 .Parameter company
  Name of the company in which the configuration package should be applied
 .Parameter credential
  Credentials to use when using UserPassword authentication (omit for Windows authentication)
 .Parameter configPackage
  Name of the configPackage to apply, this can either be a filename on the host or the name of a config package in c:\ConfigurationPackages in the container
 .Example
  UploadImportAndApply-ConfigPackageInBcContainer -containerName test2 -configPackage "W1.ENU.EVALUATION" -credential $credential
#>
function UploadImportAndApply-ConfigPackageInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $tenant = "default",
        [string] $companyName = "",
        [PSCredential] $Credential = $null,
        [Parameter(Mandatory = $true)]
        [string] $configPackage,
        [string] $packageId = ""
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $packageIdSpecified = ("$packageId" -ne "")
        if (Test-Path $configPackage -PathType Leaf) {
            $configFile = Get-Item -Path $configPackage
            if ($configFile -is [Array]) {
                throw "You can only upload, import and apply one config package at a time ($configPackage matches multiple files)"
                return
            }
            $configPackage = $configFile.FullName
            if (!$packageIdSpecified) {
                $packageInfo = Get-PackageInfoFromRapidStartFile $configPackage
                if (!($packageInfo)) {
                    $packageId = $packageInfo.Code
                }
                else {
                    $packageId = [System.IO.Path]::GetFileNameWithoutExtension($configPackage)
                    $packageId = $packageId.SubString(0, [System.Math]::Min(20, $packageId.Length))
                }
            }
        }
        else {
            $containerConfigPackage = Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($configPackage)
            (Get-item "C:\ConfigurationPackages\*$configpackage*").FullName
            } -argumentList $configPackage
            if ($containerConfigPackage) {
                if ($containerConfigPackage -is [Array]) {
                    throw "You can only upload, import and apply one config package at a time ($configPackage matches multiple files inside the container)"
                    return
                }
                if ($packageIdSpecified) {
                    $configPackage = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\$($packageId).rapidstart"
                }
                else {
                    $nameArr = "$([System.IO.Path]::GetFileNameWithoutExtension($containerConfigPackage))".Split('.')
                    $packageId = "$($nameArr[2]).$($nameArr[3]).$($nameArr[4])"
                    $configPackage = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\$($packageId).rapidstart"
                }
                if (Test-Path $configPackage) {
                    Remove-Item $configPackage -Force
                }
                Copy-FileFromBCContainer -containerName $containerName -containerPath $containerConfigPackage -localPath $configPackage
            }
            else {
                Write-Host -ForegroundColor Red "Config package $configPackage not found"
                return
            }
        }

        $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName
        if ((-not [bool]($customConfig.PSobject.Properties.name -eq "EnableTaskScheduler")) -or ($customConfig.EnableTaskScheduler -ne "True")) {
            Write-Host -ForegroundColor Red "WARNING: TaskScheduler is not enabled in the container. In order to apply configuration packages, the TaskScheduler should be enabled (use -EnableTaskScheduler on New-BcContainer)."
        }

        $CompanyId = Get-NavContainerApiCompanyId -containerName $containerName -tenant $tenant -credential $credential -APIVersion "v1.0" -CompanyName $companyName | Select-Object -First 1
        if (!($CompanyId)) {
            throw "Company $companyName doesn't exist"
        }
        else {
            Write-Host "Deleting Configuration Package $packageId (if exists)"
            try {
                Invoke-BCContainerApi -containerName $containerName `
                    -tenant $tenant `
                    -CompanyId $CompanyId `
                    -credential $credential `
                    -APIPublisher "microsoft" `
                    -APIGroup "automation" `
                    -APIVersion "v1.0" `
                    -Method "DELETE" `
                    -Query "configurationPackages('$packageId')" | Out-Null
            }
            catch {
                Write-Host "Ignoring error while deleting configuration package"
            }

            Write-Host "Creating Configuration Package $packageId"
            Invoke-BCContainerApi -containerName $containerName `
                -tenant $tenant `
                -CompanyId $CompanyId `
                -credential $credential `
                -APIPublisher "microsoft" `
                -APIGroup "automation" `
                -APIVersion "v1.0" `
                -Method "POST" `
                -Query "configurationPackages" `
                -body @{ "code" = $PackageId; "packageName" = $PackageId; } | Out-Null

            Write-Host "Uploading Configuration Package $packageId"
            Invoke-BCContainerApi -containerName $containerName `
                -tenant $tenant `
                -CompanyId $CompanyId `
                -credential $credential `
                -APIPublisher "microsoft" `
                -APIGroup "automation" `
                -APIVersion "v1.0" `
                -Method "PATCH" `
                -Query "configurationPackages('$packageId')/file('$packageId')/content" `
                -headers @{ "If-Match" = "*" } `
                -inFile $configPackage | Out-Null

            Write-Host "Importing Configuration Package $packageId"
            Invoke-BCContainerApi -containerName $containerName `
                -tenant $tenant `
                -CompanyId $CompanyId `
                -credential $credential `
                -APIPublisher "microsoft" `
                -APIGroup "automation" `
                -APIVersion "v1.0" `
                -body @{} `
                -Method "POST" `
                -Query "configurationPackages('$packageId')/Microsoft.NAV.import" | Out-Null

            $status = ""
            do {
                Start-Sleep -Seconds 5
                $result = Invoke-BCContainerApi -silent `
                    -containerName $containerName `
                    -tenant $tenant `
                    -CompanyId $CompanyId `
                    -credential $credential `
                    -APIPublisher "microsoft" `
                    -APIGroup "automation" `
                    -APIVersion "v1.0" `
                    -Method "GET" `
                    -Query "configurationPackages('$packageId')"

                $newStatus = $result.importStatus
                $continue = ($newStatus -eq "Scheduled" -or $newStatus -eq "InProgress")
                if ($status -eq $newStatus) {
                    Write-Host -NoNewline "."
                }
                else {
                    $status = $newStatus
                    Write-Host -NoNewline:$continue $status
                }
            } while ($continue)
            if ($status -eq "Error") {
                throw "Couldn't import configuration package, error is $($result.importError)"
            }
            else {
                Write-Host "Applying Configuration Package $packageId"
                Invoke-BCContainerApi -containerName $containerName `
                    -tenant $tenant `
                    -CompanyId $CompanyId `
                    -credential $credential `
                    -APIPublisher "microsoft" `
                    -APIGroup "automation" `
                    -APIVersion "v1.0" `
                    -Method "POST" `
                    -body @{} `
                    -Query "configurationPackages('$packageId')/Microsoft.NAV.apply" | Out-Null

                $status = ""
                do {
                    Start-Sleep -Seconds 5
                    $result = Invoke-BCContainerApi -silent `
                        -containerName $containerName `
                        -tenant $tenant `
                        -CompanyId $CompanyId `
                        -credential $credential `
                        -APIPublisher "microsoft" `
                        -APIGroup "automation" `
                        -APIVersion "v1.0" `
                        -Method "GET" `
                        -Query "configurationPackages('$packageId')"

                    $newStatus = $result.applyStatus
                    $continue = ($newStatus -eq "Scheduled" -or $newStatus -eq "InProgress")
                    if ($status -eq $newStatus) {
                        Write-Host -NoNewline "."
                    }
                    else {
                        $status = $newStatus
                        Write-Host -NoNewline:$continue $status
                    }
                } while ($continue)
                if ($status -eq "Error") {
                    throw "Couldn't apply configuration package, error is $($result.applyError)"
                }
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
Export-ModuleMember -Function UploadImportAndApply-ConfigPackageInBcContainer
