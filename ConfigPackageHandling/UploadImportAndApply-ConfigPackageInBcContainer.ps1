<# 
 .Synopsis
  Uploads, Imports and Applys a configuration package into a tenant in a NAV/BC Container
 .Description
  Using Management APIs, this function uploads, imports and applys a configuration package into a tenant in a NAV/BC Container
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
        [Parameter(Mandatory=$true)]
        [string] $configPackage,
        [string] $packageId = ""
    )

    if (Test-Path $configPackage -PathType Leaf) {
        $configFile = Get-Item -Path $configPackage
        if ($configFile -is [Array]) {
            throw "You can only upload, import and apply one config package at a time ($configPackage matches multiple files)"
            return
        }
        $configPackage = $configFile.FullName
        if (!$packageId) {
            $packageId = [System.IO.Path]::GetFileNameWithoutExtension($configPackage)
            $packageId = $packageId.SubString(0,[System.Math]::Min(20, $packageId.Length))
        }
    }
    else {
        $packageId = $configPackage
        $containerConfigPackage = Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($PackageId) 
            (Get-item "C:\ConfigurationPackages\*$packageId*").FullName
        } -argumentList $configPackage
        if ($containerConfigPackage) {
            if ($containerConfigPackage -is [Array]) {
                throw "You can only upload, import and apply one config package at a time  ($configPackage matches multiple files inside the container)"
                return
            }
            $configPackage = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\$([System.IO.Path]::GetFileName($containerConfigPackage))"
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
 
    $CompanyId = Get-NavContainerApiCompanyId -containerName $containerName -credential $credential -APIVersion "v1.0" -CompanyName $companyName | Select-Object -First 1
    if (!($CompanyId)) {
        throw "Company $companyName doesn't exist"
    }
    else {
        Write-Host "Deleting Configuration Package $packageId (if exists)"
        try {
            Invoke-BCContainerApi -containerName $containerName `
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
                              -CompanyId $CompanyId `
                              -credential $credential `
                              -APIPublisher "microsoft" `
                              -APIGroup "automation" `
                              -APIVersion "v1.0" `
                              -Method "POST" `
                              -Query "configurationPackages('$packageId')/Microsoft.NAV.import" | Out-Null
        
        $status = ""
        do {
            Start-Sleep -Seconds 5
            $result = Invoke-BCContainerApi -silent -containerName $containerName `
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
            throw "Couldn't import configuration package"
        }
        else {
            Write-Host "Applying Configuration Package $packageId"
            Invoke-BCContainerApi -containerName $containerName `
                                  -CompanyId $CompanyId `
                                  -credential $credential `
                                  -APIPublisher "microsoft" `
                                  -APIGroup "automation" `
                                  -APIVersion "v1.0" `
                                  -Method "POST" `
                                  -Query "configurationPackages('$packageId')/Microsoft.NAV.apply" | Out-Null
            
            $status = ""
            do {
                Start-Sleep -Seconds 5
                $result = Invoke-BCContainerApi -silent -containerName $containerName `
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
                throw "Couldn't apply configuration package"
            }
        }
    }
}
Export-ModuleMember -Function UploadImportAndApply-ConfigPackageInBcContainer
