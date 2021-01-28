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
        [switch] $useNewLine
    )

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
    }
    else {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
    }

    $appFolder = Join-Path (Get-TempDir) ([guid]::NewGuid().ToString())
    try {
        $appFiles = CopyAppFilesToFolder -appFiles $appFiles -folder $appFolder
        $baseUrl      = "https://api.businesscentral.dynamics.com/v2.0/$environment/api/microsoft/automation/v1.0"
        
        $authHeaders = @{ "Authorization" = "Bearer $($bcauthcontext.AccessToken)" }
        $companies = Invoke-RestMethod -Headers $authHeaders -Method Get -Uri "$baseurl/companies" -UseBasicParsing
        $company = $companies.value | Where-Object { ($companyName -eq "") -or ($_.name -eq $companyName) } | Select-Object -First 1
        if (!($company)) {
            throw "No company $companyName"
        }
        $companyId = $company.id
        Write-Host "Company $companyName has id $companyId"
        
        $getExtensions = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$baseUrl/companies($companyId)/extensions" -UseBasicParsing
        $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
        
        Write-Host "Extensions before:"
        $extensions | % { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
        Write-Host
        
        try {
            Sort-AppFilesByDependencies -appFiles $appFiles | ForEach-Object {
                Write-Host "$([System.IO.Path]::GetFileName($_))"
                $tempFolder = Join-Path (Get-TempDir) ([guid]::NewGuid().ToString())
                Extract-AppFileToFolder -appFilename $_ -appFolder $tempFolder -generateAppJson 6> $null
                $appJsonFile = Join-Path $tempFolder "app.json"
                $appJson = Get-Content $appJsonFile | ConvertFrom-Json
                Remove-Item -Path $tempFolder -Force -Recurse
            
                Write-Host @newLine "Publishing and Installing"
                Invoke-WebRequest -Headers ($authHeaders+(@{"If-Match" = "*"})) `
                    -Method Patch -UseBasicParsing `
                    -Uri "$baseUrl/companies($companyId)/extensionUpload(0)/content" `
                    -ContentType "application/octet-stream" `
                    -InFile $_ | Out-Null
                Write-Host @newLine "."    
                $completed = $false
                $errCount = 0
                while (!$completed)
                {
                    Start-Sleep -Seconds 5
                    try {
                        $extensionDeploymentStatusResponse = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$baseUrl/companies($companyId)/extensionDeploymentStatus" -UseBasicParsing
                        $extensionDeploymentStatuses = (ConvertFrom-Json $extensionDeploymentStatusResponse.Content).value
                        $completed = $true
                        $extensionDeploymentStatuses | Where-Object { $_.publisher -eq $appJson.publisher -and $_.name -eq $appJson.name -and $_.appVersion -eq $appJson.version } | % {
                            if ($_.status -eq "InProgress") {
                                Write-Host @newLine "."
                                $completed = $false
                            }
                            elseif ($_.Status -ne "Completed") {
                                $errCount = 5
                                throw $_.status
                            }
                        }
                        $errCount = 0
                    }
                    catch {
                        if ($errCount++ -gt 3) {
                            Write-Host $_.Exception.Message
                            throw "Unable to publish app"
                        }
                        $completed = $false
                    }
                }
                if ($completed) {
                    Write-Host "completed"
                }
            }
        }
        finally {
            $getExtensions = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$baseUrl/companies($companyId)/extensions" -UseBasicParsing
            $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
            
            Write-Host
            Write-Host "Extensions after:"
            $extensions | % { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
        }
    }
    finally {
        if (Test-Path $appFolder) {
            Remove-Item $appFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
Export-ModuleMember -Function Publish-PerTenantExtensionApps
