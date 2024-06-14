<# 
 .Synopsis
  Function for importing and applying configuration package to online tenant
 .Parameter environment
  Name of the environment inside the tenant in which you want to publish the Per Tenant Extension Apps
 .Parameter companyName
  Company Name to import the package to
 .Parameter packageFile
  File with a package to import. Package code inside file must be equal to packageCode parameter
 .Parameter packageCode
  Package will be created with specified code
 .Parameter packageName
  Package will be created with specified name
 .Parameter packageLang
  Package will be created with specified language id, en-US (1033) by default.
 .Parameter importPackage
  Enable the switch to import the package after upload
 .Parameter applyPackage
  Enable the switch to apply the package after import
 .Parameter useNewLine
  Add this switch to add a newline to progress indicating periods during wait.
  Azure DevOps doesn't update logs until a newline is added.

#>
function Import-BcConfigurationPackage {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$false)]
        [string] $companyName,
        [Parameter(Mandatory=$true)]
        $packageFile,
        [Parameter(Mandatory=$true)]
        $packageCode,
        [Parameter(Mandatory=$false)]
        $packageName = "",
        [Parameter(Mandatory=$false)]
        $packageLang = 1033,
        [switch] $importPackage,
        [switch] $applyPackage,
        [switch] $useNewLine
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $newLine = @{}
    if (!$useNewLine -and !$VerbosePreference) {
        $newLine = @{ "NoNewLine" = $true }
    }

    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext

    try {
        $automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/automation/v2.0"
        
        $authHeaders = @{ "Authorization" = "Bearer $($bcauthcontext.AccessToken)" }
        $companies = Invoke-RestMethod -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
        $company = $companies.value | Where-Object { ($companyName -eq "") -or ($_.name -eq $companyName) } | Select-Object -First 1
        if (!($company)) {
            throw "No company $companyName"
        }
        $companyId = $company.id
        Write-Host "Company $companyName has id $companyId"

        
        Write-Host "Creating configuration package:"
        $body = @{
            "code" = $packageCode
            "packageName" = $packageName
            "languageId" = $packageLang
        }
        $body | ConvertTo-Json | Out-Host

        $confPackage = Invoke-RestMethod -Headers $authHeaders -Method Post -Uri "$automationApiUrl/companies($companyId)/configurationPackages" -Body ($Body | ConvertTo-Json) -ContentType 'application/json' -Verbose:$VerbosePreference

        $confPackageId = $confPackage.id
        $confPackageCode = $confPackage.code
        Write-Host "Created configuration package $confPackageCode with id $confPackageId"


        Write-Host @newLine "Uploading package file $packageFile..."
        $response = Invoke-WebRequest -Headers ($authHeaders+(@{"If-Match" = "*"})) -Method Patch -UseBasicParsing -Uri "$automationApiUrl/companies($companyId)/configurationPackages($confPackageId)/file('$confPackageCode')/content" -ContentType 'application/octet-stream' -InFile $packageFile -Verbose:$VerbosePreference
        if ($response.StatusCode -eq 204) {
            Write-Host "Success"
        } else {
            Write-Host "Response was:"
            Write-Host $response
        }


        if ($importPackage) {
            Write-Host @newLine "Importing package"
            Invoke-RestMethod -Headers $authHeaders -Method Post -Uri "$automationApiUrl/companies($companyId)/configurationPackages($confPackageId)/Microsoft.NAV.import" -ContentType 'application/json' -Verbose:$VerbosePreference

            $completed = $false
            $sleepSeconds = 5
            while (!$completed)
            {
                Start-Sleep -Seconds $sleepSeconds

                $packageStatus = Invoke-RestMethod -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies($companyId)/configurationPackages($confPackageId)" -Verbose:$VerbosePreference

                if ($packageStatus.importStatus -eq "InProgress") {
                    Write-Host @newLine "."
                    $completed = $false
                }
                elseif ($packageStatus.importStatus -eq "Completed") {
                    Write-Host $packageStatus.importStatus
                    $completed = $true
                }
                elseif ($packageStatus.importStatus -eq "Error") {
                    Write-Host $packageStatus.importStatus
                    throw $packageStatus.importError
                }
            }
        }

        if ($importPackage -and $applyPackage) {
            Write-Host @newLine "Applying package"
            Invoke-RestMethod -Headers $authHeaders -Method Post -Uri "$automationApiUrl/companies($companyId)/configurationPackages($confPackageId)/Microsoft.NAV.apply" -ContentType 'application/json' -Verbose:$VerbosePreference

            $completed = $false
            $sleepSeconds = 5
            while (!$completed)
            {
                Start-Sleep -Seconds $sleepSeconds

                $packageStatus = Invoke-RestMethod -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies($companyId)/configurationPackages($confPackageId)" -Verbose:$VerbosePreference

                if ($packageStatus.applyStatus -eq "InProgress") {
                    Write-Host @newLine "."
                    $completed = $false
                }
                elseif ($packageStatus.applyStatus -eq "Completed") {
                    Write-Host $packageStatus.applyStatus
                    $completed = $true
                }
                elseif ($packageStatus.applyStatus -eq "Error") {
                    Write-Host $packageStatus.applyStatus
                    throw $packageStatus.applyError
                }
            }
        }
    }
    catch [System.Net.WebException] {
        Write-Host "ERROR $($_.Exception.Message)"
        throw (GetExtendedErrorMessage $_)
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
Export-ModuleMember -Function Import-BcConfigurationPackage