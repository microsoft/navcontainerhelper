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
 .Parameter hideInstalledExtensionsOutput
  Add this parameter to hide the output that lists installed extensions on the specified environment before and after installation of new and updated PTE extensions.
 .Parameter unpublishPreviousVersions
  Add this switch to unpublish previous versions of apps after upgrading to a new version.
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
        [ValidateSet('','Current version','Next minor version','Next major version')]
        [string] $schedule = '',
        [switch] $useNewLine,
        [switch] $hideInstalledExtensionsOutput,
        [switch] $unpublishPreviousVersions
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
	
    function GetAuthHeaders {
        $script:authContext = Renew-BcAuthContext -bcAuthContext $script:authContext
        return @{ "Authorization" = "Bearer $($script:authContext.AccessToken)" }
    }

    $newLine = @{}
    if (!$useNewLine) {
        $newLine = @{ "NoNewLine" = $true }
    }

    if ($PsCmdlet.ParameterSetName -eq "CC") {
        if ($clientId -is [SecureString]) { $clientID = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientID)) }
        if ($clientId -isnot [String]) { throw "ClientID needs to be a SecureString or a String" }
        if ($clientSecret -is [String]) { $clientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force }
        if ($clientSecret -isnot [SecureString]) { throw "ClientSecret needs to be a SecureString or a String" }

        $script:authContext = New-BcAuthContext `
            -clientID $clientID `
            -clientSecret $clientSecret `
            -tenantID $tenantId `
            -scopes "https://api.businesscentral.dynamics.com/.default"

        if (-not ($script:AuthContext)) {
            throw "Authentication failed"
        }
    }
    else {
        $script:authContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    }

    $appFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    try {
        $appFiles = CopyAppFilesToFolder -appFiles $appFiles -folder $appFolder
        $automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/automation/v2.0"
        
        Write-Host "$automationApiUrl/companies"
        $companies = Invoke-RestMethod -Headers (GetAuthHeaders) -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
        $company = $companies.value | Where-Object { ($companyName -eq "") -or ($_.name -eq $companyName) } | Select-Object -First 1
        if (!($company)) {
            throw "No company $companyName"
        }
        $companyId = $company.id
        if ($companyName -eq "") {
            $companyName = $company.name
        }
        Write-Host "Company '$companyName' has id $companyId"
        
        Write-Host "$automationApiUrl/companies($companyId)/extensions"
        $getExtensions = Invoke-WebRequest -Headers (GetAuthHeaders) -Method Get -Uri "$automationApiUrl/companies($companyId)/extensions" -UseBasicParsing
        $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
        
        if(!$hideInstalledExtensionsOutput) {
            Write-Host "Extensions before:"
            $extensions | ForEach-Object { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
            Write-Host
        }

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

        if($schedule) {
            $body."schedule" = $schedule
        }

        $ifMatchHeader = @{ "If-Match" = '*'}
        $jsonHeader = @{ "Content-Type" = 'application/json'}
        $streamHeader = @{ "Content-Type" = 'application/octet-stream'}
        try {
            Sort-AppFilesByDependencies -appFiles $appFiles -excludeRuntimePackages | ForEach-Object {
                $appFile = $_
                Write-Host @newline "$([System.IO.Path]::GetFileName($appFile)) - "
                $appJson = Get-AppJsonFromAppFile -appFile $appFile
                $previousApp = $null
                $existingApp = $extensions | Where-Object { $_.id -eq $appJson.id -and $_.isInstalled }
                if ($existingApp) {
                    if ($existingApp.isInstalled) {
                        $existingVersion = [System.Version]"$($existingApp.versionMajor).$($existingApp.versionMinor).$($existingApp.versionBuild).$($existingApp.versionRevision)"
                        if ($existingVersion -ge $appJson.version) {
                            Write-Host "already installed"
                        }
                        else {
                            Write-Host @newLine "upgrading"
                            $previousApp = $existingApp
                            $existingApp = $null
                        }
                    }
                    else {
                        Write-Host @newLine "installing"
                        $existingApp = $null
                    }
                }
                else {
                    Write-Host @newLine "publishing and installing"
                }
                if (!$existingApp) {
                    $extensionUpload = (Invoke-RestMethod -Method Get -Uri "$automationApiUrl/companies($companyId)/extensionUpload" -Headers (GetAuthHeaders)).value
                    Write-Host @newLine "."
                    if ($extensionUpload -and $extensionUpload.systemId) {
                        $extensionUpload = Invoke-RestMethod `
                            -Method Patch `
                            -Uri "$automationApiUrl/companies($companyId)/extensionUpload($($extensionUpload.systemId))" `
                            -Headers ((GetAuthHeaders) + $ifMatchHeader + $jsonHeader) `
                            -Body ($body | ConvertTo-Json -Compress)
                    }
                    else {
                        $ExtensionUpload = Invoke-RestMethod `
                            -Method Post `
                            -Uri "$automationApiUrl/companies($companyId)/extensionUpload" `
                            -Headers ((GetAuthHeaders) + $jsonHeader) `
                            -Body ($body | ConvertTo-Json -Compress)
                    }
                    Write-Host @newLine "."
                    if ($null -eq $extensionUpload.systemId) {
                        throw "Unable to upload extension"
                    }
                    # Use stream instead of reading the entire file into memory
                    $fileStream = [System.IO.File]::OpenRead($appFile)
                    Invoke-RestMethod `
                        -Method Patch `
                        -Uri $extensionUpload.'extensionContent@odata.mediaEditLink' `
                        -Headers ((GetAuthHeaders) + $ifMatchHeader + $streamHeader) `
                        -Body $fileStream | Out-Null
                    $fileStream.Close()
                    Write-Host @newLine "."
                    Invoke-RestMethod `
                        -Method Post `
                        -Uri "$automationApiUrl/companies($companyId)/extensionUpload($($extensionUpload.systemId))/Microsoft.NAV.upload" `
                        -Headers ((GetAuthHeaders) + $ifMatchHeader) `
                        -ErrorAction SilentlyContinue | Out-Null
                    Write-Host @newLine "."    
                    $completed = $false
                    $errCount = 0
                    $sleepSeconds = 30
                    $lastStatus = ''
                    while (!$completed)
                    {
                        Start-Sleep -Seconds $sleepSeconds
                        try {
                            $extensionDeploymentStatusResponse = Invoke-WebRequest -Headers (GetAuthHeaders) -Method Get -Uri "$automationApiUrl/companies($companyId)/extensionDeploymentStatus" -UseBasicParsing
                            $extensionDeploymentStatuses = (ConvertFrom-Json $extensionDeploymentStatusResponse.Content).value

                            $thisExtension = $extensionDeploymentStatuses | Where-Object { $_.publisher -eq $appJson.publisher -and $_.name -eq $appJson.name -and $_.appVersion -eq $appJson.version }
                            if ($null -eq $thisExtension) {
                                throw "Unable to find extension deployment status"
                            } 
                            $thisExtension | ForEach-Object {
                                if ($_.status -ne $lastStatus) {
                                    if (!$useNewLine) { Write-Host }
                                    Write-Host @newLine $_.status
                                    $lastStatus = $_.status
                                }
                                if ($_.status -eq "InProgress") {
                                    $errCount = 0
                                    $sleepSeconds = 5
                                    Write-Host @newLine "."
                                }
                                elseif ($_.Status -eq "Unknown") {
                                    throw "Unknown Error"
                                }
                                elseif ($_.Status -eq "Completed") {
                                    if (!$useNewLine) { Write-Host }
                                    $completed = $true
                                }
                                else {
                                    $errCount = 5
                                    throw $_.status
                                }
                            }
                        }
                        catch {
                            if (!$useNewLine) { Write-Host }
                            if ($errCount++ -gt 4) {
                                Write-Host $_.Exception.Message
                                throw "Unable to publish app. Please open the Extension Deployment Status Details page in Business Central to see the detailed error message."
                            }
                            $sleepSeconds += $sleepSeconds
                            Write-Host "Error: $($_.Exception.Message). Retrying in $sleepSeconds seconds"
                        }
                    }
                    if ($unpublishPreviousVersions -and $previousApp -and ($appDepVer -ge [System.Version]"25.4.0.0")) { # New unpublish API available from 25.4
                        Write-Host @newLine "Unpublishing previous version"
                        Invoke-RestMethod `
                            -Method Post `
                            -Uri "$automationApiUrl/companies($companyId)/extensions($($previousApp.packageId))/Microsoft.NAV.unpublish" `
                            -Headers (GetAuthHeaders) | Out-Null
                    }
                }
            }
        }
        catch [System.Net.WebException],[System.Net.Http.HttpRequestException] {
            if (!$useNewLine) { Write-Host }
            Write-Host "ERROR $($_.Exception.Message)"
            Write-Host $_.ScriptStackTrace
            throw (GetExtendedErrorMessage $_)
        }
        catch {
            if (!$useNewLine) { Write-Host }
            Write-Host "ERROR: $($_.Exception.Message) [$($_.Exception.GetType().FullName)]"
            throw
        }
        finally {
            $getExtensions = Invoke-WebRequest -Headers (GetAuthHeaders) -Method Get -Uri "$automationApiUrl/companies($companyId)/extensions" -UseBasicParsing
            $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
            
            if (!$hideInstalledExtensionsOutput) {
                Write-Host
                Write-Host "Extensions after:"
                $extensions | ForEach-Object { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
            }
        }
    }
    catch [System.Net.WebException],[System.Net.Http.HttpRequestException] {
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
    $script:authContext = $null
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Publish-PerTenantExtensionApps
