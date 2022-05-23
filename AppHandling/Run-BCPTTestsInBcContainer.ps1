<# 
 .Synopsis
  Run a BCPT test suite in a BC Container
 .Description
 .Parameter containerName
  Name of the container in which you want to run a BCPT test suite
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter companyName
  company to use
 .Parameter profile
  profile to use
 .Parameter credential
  Credentials of the SUPER user if using NavUserPassword authentication
 .Parameter TestPage
  Specifying a TestPage causes the performacne test tool to use this page for perf test execution
 .Parameter BCPTSuite
  PSCustomObject or HashTable containing your BCPT Suite for importing
 .Parameter SuiteCode
  The suite code ot the BCPT Test to run
 .Parameter doNotGetResults
  Include this switch to NOT query the BCPT Log Entry API for the results
 .Example
  Run-BCPTTestsInBcContainer -containerName test -credential $credential -suiteCode $suite.code
#>
function Run-BCPTTestsInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [string] $companyName = "",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [string] $testPage = "149002",
        [switch] $doNotGetResults,
        [Parameter(Mandatory = $true,  ParameterSetName = 'Suite')]
        $BCPTSuite,
        [Parameter(Mandatory = $true,  ParameterSetName = 'SuiteCode')]
        [string] $suiteCode,
        [switch] $connectFromHost
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    
    $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
    $version = [System.Version]($navversion.split('-')[0])
    if ($version.Major -lt 18) {
        throw "Run-BCPTTestsInBcContainer is not supported for versions prior to 18.0"
    }
    $pre20 = ($version.Major -lt 20)

    if ($pre20) {
        $BCPTLogEntryAPIsrc = Join-Path $PSScriptRoot "BCPTLogEntryAPI"
        $appJson = [System.IO.File]::ReadAllLines((Join-Path $BCPTLogEntryAPIsrc "app.json")) | ConvertFrom-Json
        if (-not (Get-BcContainerAppInfo -containerName $containerName | Where-Object { $_.appId -eq $appJson.id })) {
            Write-Host "Adding BCPTLogEntryAPI.app to extend existing Performance Toolkit with BCPTLogEntry API page"
            Write-Host "Using Object Id $($bcContainerHelperConfig.ObjectIdForInternalUse) (set `$bcContainerHelperConfig.ObjectIdForInternalUse to change)"
            $appExtFolder = Join-Path $hosthelperfolder "Extensions\$containerName\$([GUID]::NewGuid().ToString())"
            New-Item $appExtFolder -ItemType Directory | Out-Null
            $appJson.idRanges[0].from = $bcContainerHelperConfig.ObjectIdForInternalUse
            $appJson.idRanges[0].to = $bcContainerHelperConfig.ObjectIdForInternalUse
            $appJson | ConvertTo-Json -Depth 99 | Set-Content (Join-Path $appExtFolder "app.json")
            $appExtSrc = Get-Content -Path (Join-Path $BCPTLogEntryAPIsrc "BCPTLogEntryAPI.Page.al")
            $appExtSrc[0] = "page $($bcContainerHelperConfig.ObjectIdForInternalUse) ""BCPT Log Entry API"""
            $appExtSrc | Set-Content (Join-Path $appExtFolder "BCPTLogEntryAPI.Page.al")
    
            $appExtFileName = Compile-AppInBcContainer `
                -containerName $containerName `
                -appProjectFolder $appExtFolder `
                -credential $credential `
                -UpdateSymbols
            
            Publish-BcContainerApp `
                -containerName $containerName `
                -tenant $tenant `
                -appFile $appExtFileName `
                -skipVerification `
                -sync `
                -install
        }
    }

    if ("$companyName" -eq "") {
        $myName = $credential.UserName.SubString($credential.UserName.IndexOf('\')+1)
        Get-BcContainerBcUser -containerName $containerName | Where-Object { $_.UserName -like "*\$MyName" -or $_.UserName -eq $myName } | % {
            $companyName = $_.Company
        }
        if ($companyName) { Write-Host "Using CompanyName $companyName" }
    }

    if ("$companyName" -eq "") {
        $companyName = Get-CompanyInBcContainer -containerName $containerName -tenant $tenant | Select-Object -First 1 | ForEach-Object { $_.CompanyName }
        if ($companyName) { Write-Host "Using CompanyName $companyName" }
    }
    
    if (($BCPTSuite) -or (!$doNotGetResults)) {
        $companyId = Get-BcContainerApiCompanyId `
            -containerName $containerName `
            -tenant $tenant `
            -credential $credential `
            -CompanyName $companyName
        Write-Host "Using Company ID $companyId"
    }

    $durationString = ""
    if ($BCPTSuite) {
        if ($BCPTSuite -is [PSCustomObject]) {
            $BCPTSuite = $BCPTSuite | ConvertTo-HashTable
        }
        if ($BCPTSuite -isnot [HashTable]) {
            throw "BCPTSuite must be PSCustomObject or HashTable"
        }

        Invoke-BcContainerApi `
            -containerName $containerName `
            -tenant $tenant `
            -credential $credential `
            -CompanyId $companyId `
            -APIPublisher 'Microsoft' `
            -APIGroup 'PerformancToolkit' `
            -APIVersion 'v1.0' `
            -Method 'POST' `
            -body $BCPTSuite `
            -Query 'bcptSuites' | Out-Null

        $suiteCode = $BCPTSuite.Code
        $durationString = " for $($BCPTSuite.durationInMinutes) minutes"
    }

    $config = Get-BcContainerServerConfiguration -containerName $containerName
    if ($connectFromHost) {
        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
            Copy-Item -path "C:\Applications\testframework\TestRunner" -Destination "c:\run\my" -Recurse -Force
        }
        $auth = $config.ClientServicesCredentialType
        if ($auth -eq "UserPassword") { $auth = "NavUserPassword" }
        $params = @{ "AuthorizationType" = $auth }
        if ($auth -ne "Windows") { $params += @{ "Credential" = $credential } }
        $serviceUrl = "$($config.PublicWebBaseUrl.TrimEnd('/'))/cs/?tenant=$tenant&company=$([Uri]::EscapeDataString($companyName))"
        Write-Host "Using testpage $testpage"
        Write-Host "Using Suitecode $suitecode"
        Write-Host "Service Url $serviceUrl"
        Write-Host "Running Performance Tests$($durationString)..."

        $Job = Start-Job -ScriptBlock { Param( $location, [HashTable] $params, $suitecode, $serviceUrl, $testPage)
            Set-Location $location
            .\RunBCPTTests.ps1 @params `
                -BCPTTestRunnerInternalFolderPath Internal `
                -SuiteCode $suitecode `
                -ServiceUrl $serviceUrl `
                -Environment OnPrem `
                -TestRunnerPage ([int]$testPage) | Out-Null
        } -ArgumentList (Join-Path $hosthelperfolder "extensions\$containerName\my\TestRunner"), $params, $suiteCode, $serviceUrl, $testPage | Wait-Job

        if ($job.State -ne "Completed") {
            Write-Host "Running performance test failed"
            $job | Receive-Job | Out-Host
        }
        $job | Remove-Job | Out-Null
    }
    else {
        Invoke-ScriptInBcContainer -containerName $containerName -useSession:$false -scriptblock { Param($webBaseUrl, $tenant, $companyName, $testPage, $auth, $credential, $suitecode, $durationString)

            Set-Location C:\Applications\testframework\TestRunner
            if ($auth -eq "UserPassword") { $auth = "NavUserPassword" }
            $params = @{ "AuthorizationType" = $auth }
            if ($auth -ne "Windows") { $params += @{ "Credential" = $credential } }
            $serviceUrl = "http://localhost:80/$serverInstance/cs/?tenant=$tenant&company=$([Uri]::EscapeDataString($companyName))"
            Write-Host "Using testpage $testpage"
            Write-Host "Using Suitecode $suitecode"
            Write-Host "Service Url $serviceUrl"
            Write-Host "Running Performance Tests$($durationString)..."
    
            .\RunBCPTTests.ps1 @params `
                -BCPTTestRunnerInternalFolderPath Internal `
                -SuiteCode $suitecode `
                -ServiceUrl $serviceUrl `
                -Environment OnPrem `
                -TestRunnerPage ([int]$testPage) | Out-Null
    
        } -argumentList $config.PublicWebBaseUrl, $tenant, $companyName, $testPage, $config.ClientServicesCredentialType, $credential, $suitecode, $durationString
    }

    if (!$doNotGetResults) {
        $response = Invoke-BcContainerApi `
            -containerName $containerName `
            -tenant $tenant `
            -credential $credential `
            -CompanyId $companyId `
            -APIPublisher 'Microsoft' `
            -APIGroup 'PerformancToolkit' `
            -APIVersion 'v1.0' `
            -Method 'GET' `
            -Query 'bcptLogEntries'
        
        $response.value
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
Export-ModuleMember -Function Run-BCPTTestsInBcContainer
