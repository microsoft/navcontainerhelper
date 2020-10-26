<# 
 .Synopsis
  Preview function for publishing PTE apps to an online tenant
 .Description
  Preview function for publishing PTE apps to an online tenant
#>
function Publish-PerTenantExtensionApps {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $clientId,
        [Parameter(Mandatory=$true)]
        [string] $clientSecret,
        [Parameter(Mandatory=$true)]
        [string] $tenantId,
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

    $loginURL     = "https://login.microsoftonline.com"
    $scopes       = "https://api.businesscentral.dynamics.com/.default"
    $baseUrl      = "https://api.businesscentral.dynamics.com/v2.0/$environment/api/microsoft/automation/v1.0"
    
    Write-Host "Authenticating to $tenantId using $ClientId"
    $body = @{grant_type="client_credentials";scope=$scopes;client_id=$ClientID;client_secret=$ClientSecret}
    $oauth = Invoke-RestMethod -Method Post -Uri $("$loginURL/$tenantId/oauth2/v2.0/token") -Body $body
    $authHeaders = @{ "Authorization" = "Bearer $($oauth.access_token)" }
    Write-Host "Authenticated"
    
    $companies = Invoke-RestMethod -Headers $authHeaders -Method Get -Uri "$baseurl/companies"
    $company = $companies.value | Where-Object { ($companyName -eq "") -or ($_.name -eq $companyName) } | Select-Object -First 1
    if (!($company)) {
        throw "No company $companyName"
    }
    $companyId = $company.id
    Write-Host "Company $companyName has id $companyId"
    
    $getExtensions = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$baseUrl/companies($companyId)/extensions"
    $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
    
    Write-Host "Extensions before:"
    $extensions | % { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
    Write-Host
    
    Sort-AppFilesByDependencies -appFiles $appFiles | ForEach-Object {
        $tempFolder = Join-Path $ENV:TEMP ([guid]::NewGuid().ToString())
    
        Extract-AppFileToFolder -appFilename $_ -appFolder c:\temp\appcontent -generateAppJson 6> $null
        $appJsonFile = "c:\temp\appcontent\app.json"
        $appJson = Get-Content $appJsonFile | ConvertFrom-Json
        Remove-Item -Path c:\temp\appcontent -Force -Recurse
    
        Write-Host @newLine "Publishing and Installing $([System.IO.Path]::GetFileName($_))"
        Invoke-WebRequest -Headers ($authHeaders+(@{"If-Match" = "*"})) `
            -Method Patch `
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
                $extensionDeploymentStatusResponse = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$baseUrl/companies($companyId)/extensionDeploymentStatus"
                $extensionDeploymentStatuses = (ConvertFrom-Json $extensionDeploymentStatusResponse.Content).value
                $completed = $true
                $extensionDeploymentStatuses | Where-Object { $_.publisher -eq $appJson.publisher -and $_.name -eq $appJson.name -and $_.appVersion -eq $appJson.version } | % {
                    if ($_.status -eq "InProgress") {
                        Write-Host @newLine "."
                        $completed = $false
                    }
                    elseif ($_.Status -ne "Completed") {
                        $errCount = 5
                        throw "error"
                    }
                }
                $errCount = 0
            }
            catch {
                if ($errCount++ -gt 3) {
                    Write-Host "error"
                    throw "Unable to publish app"
                }
                $completed = $false
            }
        }
        if ($completed) {
            Write-Host "completed"
        }
    }
    
    $getExtensions = Invoke-WebRequest -Headers $authHeaders -Method Get -Uri "$baseUrl/companies($companyId)/extensions"
    $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName
    
    Write-Host
    Write-Host "Extensions after:"
    $extensions | % { Write-Host " - $($_.DisplayName), Version $($_.versionMajor).$($_.versionMinor).$($_.versionBuild).$($_.versionRevision), Installed=$($_.isInstalled)" }
}
Export-ModuleMember -Function Publish-PerTenantExtensionApps
