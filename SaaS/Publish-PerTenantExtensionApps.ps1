<# 
 .Synopsis
  Function for publishing PTE apps to an online tenant
 .Description
  Function for publishing PTE apps to an online tenant
  Please consult the CI/CD Workshop document at http://aka.ms/cicdhol to learn more about this function
 .Parameter clientId
  ClientID of Azure AD App for authenticating to Business Central (SecureString or String)
 .Parameter clientSecret
  ClientSecret of Azure AD App for authenticating to Business Central (SecureString or String)
 .Parameter tenantId
  TenantId of tenant in which you want to publish the Per Tenant Extension Apps
 .Parameter environment
  Name of the environment inside the tenant in which you want to publish the Per Tenant Extension Apps
 .Parameter companyName
  Company Name in which the Azure AD App is registered
 .Parameter appFiles
  Array or comma separated string of apps or .zip files containing apps, which needs to be published
  The apps will be sorted by dependencies and published+installed
 .Parameter useNewLine
  Add this switch to add a newline to progress indicating periods during wait.
  Azure DevOps doesn't update logs until a newline is added.

#>
function Publish-PerTenantExtensionApps {
    [CmdletBinding(DefaultParameterSetName="AC")]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="CC")]
        $clientId,
        [Parameter(Mandatory=$true, ParameterSetName="CC")]
        $clientSecret,
        [Parameter(Mandatory=$true, ParameterSetName="CC")]
        [string] $tenantId,
        [Parameter(Mandatory=$true, ParameterSetName="AC")]
        [Hashtable] $bcAuthContext,
        [Parameter(Mandatory=$true)]
        [string] $environment,
        [Parameter(Mandatory=$false)]
        [string] $companyName,
        [Parameter(Mandatory=$true)]
        $appFiles,
        [ValidateSet('Add','Force')]
        [string] $schemaSyncMode = 'Add',
        [switch] $useNewLine
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
	
    $newLine = @{}
    if (!$useNewLine) {
        $newLine = @{ "NoNewLine" = $true }
    }

    if ($PsCmdlet.ParameterSetName -eq "CC") {
        if ($clientId -is [SecureString]) { $clientID = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientID)) }
        if ($clientId -isnot [String]) { throw "ClientID needs to be a SecureString or a String" }
        if ($clientSecret -is [String]) { $clientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force }
        if ($clientSecret -isnot [SecureString]) { throw "ClientSecret needs to be a SecureString or a String" }

        $bcauthContext = New-BcAuthContext `
            -clientID $clientID `
            -clientSecret $clientSecret `
            -tenantID $tenantId `
            -scopes "https://api.businesscentral.dynamics.com/.default"

        if (-not ($bcAuthContext)) {
            throw "Authentication failed"
        }
    }
    else {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    }

    $appFolder = Join-Path (Get-TempDir) ([guid]::NewGuid().ToString())
    try {
        $appFiles = CopyAppFilesToFolder -appFiles $appFiles -folder $appFolder
        $automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/automation/v2.0"
        
        $authHeaders = @{ "Authorization" = "Bearer $($bcauthcontext.AccessToken)" }
        $companies = Invoke-RestMethod -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
        $company = $companies.value | Where-Object { ($companyName -eq "") -or ($_.name -eq $companyName) } | Select-Object -First 1
        if (!($company)) {
            throw "No company $companyName"
        }
        $companyId = $company.id
        Write-Host "Company $companyName has id $companyId"
        
        $getExtensions = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies($companyId)/extensions" -UseBasicParsing
        $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
        
        Write-Host "Extensions before:"
        $extensions | ForEach-Object { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
        Write-Host

        $body = @{"schedule" = "Current Version"}
        $appDep = $extensions | Where-Object { $_.DisplayName -eq 'Application' }
        $appDepVer = [System.Version]"$($appDep.versionMajor).$($appDep.versionMinor).$($appDep.versionBuild).$($appDep.versionRevision)"
        if ($appDepVer -ge [System.Version]"21.2.0.0") {
            if ($schemaSyncMode -eq 'Force') {
                $body."SchemaSyncMode" = "Force Sync"
            }
            else {
                $body."SchemaSyncMode" = "Add"
            }
        }
        else {
            if ($schemaSyncMode -eq 'Force') {
                throw 'SchemaSyncMode Force is not supported before version 21.2'
            }
        }
        $ifMatchHeader = @{ "If-Match" = '*'}
        $jsonHeader = @{ "Content-Type" = 'application/json'}
        $streamHeader = @{ "Content-Type" = 'application/octet-stream'}
        try {
            Sort-AppFilesByDependencies -appFiles $appFiles | ForEach-Object {
                Write-Host "$([System.IO.Path]::GetFileName($_))"
                $tempFolder = Join-Path (Get-TempDir) ([guid]::NewGuid().ToString())
                Extract-AppFileToFolder -appFilename $_ -appFolder $tempFolder -generateAppJson 6> $null
                $appJsonFile = Join-Path $tempFolder "app.json"
                $appJson = [System.IO.File]::ReadAllLines($appJsonFile) | ConvertFrom-Json
                Remove-Item -Path $tempFolder -Force -Recurse
                $body | ConvertTo-Json | out-host
                Write-Host @newLine "Publishing and Installing"
                $extensionUpload = (Invoke-RestMethod -Method Get -Uri "$automationApiUrl/companies($companyId)/extensionUpload" -Headers $authHeaders).value
                Write-Host @newLine "."
                if ($extensionUpload -and $extensionUpload.systemId) {
                    $extensionUpload = Invoke-RestMethod `
                        -Method Patch `
                        -Uri "$automationApiUrl/companies($companyId)/extensionUpload($($extensionUpload.systemId))" `
                        -Headers ($authHeaders + $ifMatchHeader + $jsonHeader) `
                        -Body ($body | ConvertTo-Json -Compress)
                }
                else {
                    $ExtensionUpload = Invoke-RestMethod `
                        -Method Post `
                        -Uri "$automationApiUrl/companies($companyId)/extensionUpload" `
                        -Headers ($authHeaders + $jsonHeader) `
                        -Body ($body | ConvertTo-Json -Compress)
                }
                Write-Host @newLine "."
                if ($null -eq $extensionUpload.systemId) {
                    throw "Unable to upload extension"
                }
                $body = (Invoke-WebRequest $_).Content
                Invoke-RestMethod `
                    -Method Patch `
                    -Uri $extensionUpload.'extensionContent@odata.mediaEditLink' `
                    -Headers ($authHeaders + $ifMatchHeader + $streamHeader) `
                    -Body $body | Out-Null
                Write-Host @newLine "."    
                Invoke-RestMethod `
                    -Method Post `
                    -Uri "$automationApiUrl/companies($companyId)/extensionUpload($($extensionUpload.systemId))/Microsoft.NAV.upload" `
                    -Headers ($authHeaders + $ifMatchHeader) | Out-Null
                Write-Host @newLine "."    
                $completed = $false
                $errCount = 0
                $sleepSeconds = 5
                while (!$completed)
                {
                    Start-Sleep -Seconds $sleepSeconds
                    try {
                        $extensionDeploymentStatusResponse = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies($companyId)/extensionDeploymentStatus" -UseBasicParsing
                        $extensionDeploymentStatuses = (ConvertFrom-Json $extensionDeploymentStatusResponse.Content).value

                        $completed = $true
                        $extensionDeploymentStatuses | Where-Object { $_.publisher -eq $appJson.publisher -and $_.name -eq $appJson.name -and $_.appVersion -eq $appJson.version } | % {
                            if ($_.status -eq "InProgress") {
                                Write-Host @newLine "."
                                $completed = $false
                            }
                            elseif ($_.Status -eq "Unknown") {
                                throw "Unknown Error"
                            }
                            elseif ($_.Status -ne "Completed") {
                                $errCount = 5
                                throw $_.status
                            }
                        }
                        $errCount = 0
                        $sleepSeconds = 5
                    }
                    catch {
                        if ($errCount++ -gt 4) {
                            Write-Host $_.Exception.Message
                            throw "Unable to publish app. Please open the Extension Deployment Status Details page in Business Central to see the detailed error message."
                        }
                        $sleepSeconds += $sleepSeconds
                        $completed = $false
                    }
                }
                if ($completed) {
                    Write-Host "completed"
                }
            }
        }
        catch [System.Net.WebException] {
            Write-Host "ERROR $($_.Exception.Message)"
            Write-Host $_.ScriptStackTrace
            throw (GetExtendedErrorMessage $_)
        }
        finally {
            $getExtensions = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$automationApiUrl/companies($companyId)/extensions" -UseBasicParsing
            $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
            
            Write-Host
            Write-Host "Extensions after:"
            $extensions | ForEach-Object { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
        }
    }
    catch [System.Net.WebException] {
        Write-Host "ERROR $($_.Exception.Message)"
        throw (GetExtendedErrorMessage $_)
    }
    finally {
        if (Test-Path $appFolder) {
            Remove-Item $appFolder -Recurse -Force -ErrorAction SilentlyContinue
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
Export-ModuleMember -Function Publish-PerTenantExtensionApps
