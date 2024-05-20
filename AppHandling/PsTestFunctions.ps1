﻿Param(
    [Parameter(Mandatory=$true)]
    [string] $clientDllPath,
    [Parameter(Mandatory=$true)]
    [string] $newtonSoftDllPath,
    [string] $clientContextScriptPath = $null
)

# Load DLL's
Add-type -Path $clientDllPath
Add-type -Path $newtonSoftDllPath

if (!($clientContextScriptPath)) {
    $clientContextScriptPath = Join-Path $PSScriptRoot "ClientContext.ps1"
}

. $clientContextScriptPath -clientDllPath $clientDllPath

function New-ClientContext {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $serviceUrl,
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string] $auth='NavUserPassword',
        [Parameter(Mandatory=$false)]
        [pscredential] $credential,
        [timespan] $interactionTimeout = [timespan]::FromMinutes(10),
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode
    )

    if ($auth -eq "Windows") {
        $clientContext = [ClientContext]::new($serviceUrl, $interactionTimeout, $culture, $timezone)
    }
    elseif ($auth -eq "NavUserPassword") {
        if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
            throw "You need to specify credentials if using NavUserPassword authentication"
        }
        $clientContext = [ClientContext]::new($serviceUrl, $credential, $interactionTimeout, $culture, $timezone)
    }
    elseif ($auth -eq "AAD") {

        if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
            throw "You need to specify credentials (Username and AccessToken) if using AAD authentication"
        }
        $accessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password))
        $clientContext = [ClientContext]::new($serviceUrl, $accessToken, $interactionTimeout, $culture, $timezone)
    }
    else {
        throw "Unsupported authentication setting"
    }
    if ($clientContext) {
        $clientContext.debugMode = $debugMode
    }
    return $clientContext
}

function Remove-ClientContext {
    Param(
        [ClientContext] $clientContext
    )
    if ($clientContext) {
        $clientContext.Dispose()
    }
}

function Dump-ClientContext {
    Param(
        [ClientContext] $clientContext
    )
    if ($clientContext) {
        $clientContext.GetAllForms() | % {
            $formInfo = $clientContext.GetFormInfo($_)
            if ($formInfo) {
                Write-Host -ForegroundColor Yellow "Title: $($formInfo.title)"
                Write-Host -ForegroundColor Yellow "Title: $($formInfo.identifier)"
                $formInfo.controls | ConvertTo-Json -Depth 99 | Out-Host
            }
        }
    }
}

function Set-ExtensionId
(
    [string] $ExtensionId,
    [ClientContext] $ClientContext,
    [switch] $debugMode,
    $Form
)
{
    if(!$ExtensionId)
    {
        return
    }
    
    if ($debugMode) {
        Write-Host "Setting Extension Id $ExtensionId"
    }
    $extensionIdControl = $ClientContext.GetControlByName($Form, "ExtensionId")
    $ClientContext.SaveValue($extensionIdControl, $ExtensionId)
}

function Set-TestCodeunitRange
(
    [string] $testCodeunitRange,
    [ClientContext] $ClientContext,
    [switch] $debugMode,
    $Form
) {
    Write-Host "Setting test codeunit range '$testCodeunitRange'"
    if (!$testCodeunitRange) { return }
    if ($testCodeunitRange -eq "*") { $testCodeunitRange = "0.." }

    if ($debugMode) {
        Write-Host "Setting test codeunit range '$testCodeunitRange'"
    }
    $testCodeunitRangeControl = $ClientContext.GetControlByName($Form, "TestCodeunitRangeFilter")
    if ($null -eq $testCodeunitRangeControl) { 
        if ($debugMode) { Write-Host "Test codeunit range control not found on test page" }
        return 
    }
    $ClientContext.SaveValue($testCodeunitRangeControl, $testCodeunitRange)
}

function Set-TestRunnerCodeunitId
(
    [string] $testRunnerCodeunitId,
    [ClientContext] $ClientContext,
    [switch] $debugMode,
    $Form
)
{
    if(!$testRunnerCodeunitId)
    {
        return
    }
    
    if ($debugMode) {
        Write-Host "Setting Test Runner Codeunit Id $testRunnerCodeunitId"
    }
    $testRunnerCodeunitIdControl = $ClientContext.GetControlByName($Form, "TestRunnerCodeunitId")
    $ClientContext.SaveValue($testRunnerCodeunitIdControl, $testRunnerCodeunitId)
}

function Set-RunFalseOnDisabledTests
(
    [ClientContext] $ClientContext,
    [array] $DisabledTests,
    [switch] $debugMode,
    $Form
)
{
    if(!$DisabledTests)
    {
        return
    }

    $removeTestMethodControl = $ClientContext.GetControlByName($Form, "DisableTestMethod")
    foreach($disabledTestMethod in $DisabledTests)
    {
        $disabledTestMethod.method | ForEach-Object {
            if ($disabledTestMethod.codeunitName.IndexOf(',') -ge 0) {
                Write-Host "Warning: Cannot disable tests in codeunits with a comma in the name ($($disabledTestMethod.codeunitName):$_)"
            }
            else {
                if ($debugMode) {
                    Write-Host "Disabling Test $($disabledTestMethod.codeunitName):$_"
                }
                $testKey = "$($disabledTestMethod.codeunitName),$_"
                $ClientContext.SaveValue($removeTestMethodControl, $testKey)
            }
        }
    }
}

function Set-CCTrackingType
{
    param (
        [ValidateSet('Disabled', 'PerRun', 'PerCodeunit', 'PerTest')]
        [string] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    $TypeValues = @{
        Disabled = 0
        PerRun = 1
        PerCodeunit=2
        PerTest=3
    }
    $suiteControl = $ClientContext.GetControlByName($Form, "CCTrackingType")
    $ClientContext.SaveValue($suiteControl, $TypeValues[$Value])
}

function Set-CCExporterID
{
    param (
        [string] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    if($Value){
        $suiteControl = $ClientContext.GetControlByName($Form, "CCExporterID");
        $ClientContext.SaveValue($suiteControl, $Value)
    }
}

function Set-CCProduceCodeCoverageMap
{

    param (
        [ValidateSet('Disabled', 'PerCodeunit', 'PerTest')]
        [string] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    $TypeValues = @{
        Disabled = 0
        PerCodeunit = 1
        PerTest=2
    }
    $suiteControl = $ClientContext.GetControlByName($Form, "CCMap")
    $ClientContext.SaveValue($suiteControl, $TypeValues[$Value])
}

function Clear-CCResults
{
    param (
        [ClientContext] $ClientContext,
        $Form
    )
    $ClientContext.InvokeAction($ClientContext.GetActionByName($Form, "ClearCodeCoverage"))
}

function CollectCoverageResults {
    param (
        [ValidateSet('PerRun', 'PerCodeunit', 'PerTest')]
        [string] $TrackingType,
        [string] $OutputPath,
        [switch] $DisableSSLVerification,
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string] $AutorizationType = $script:DefaultAuthorizationType,
        [Parameter(Mandatory=$false)]
        [pscredential] $Credential,
        [Parameter(Mandatory=$true)]
        [string] $ServiceUrl,
        [string] $CodeCoverageFilePrefix
    )
    try{
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        $form = Open-TestForm -TestPage $TestPage -ClientContext $clientContext
        do {
            $clientContext.InvokeAction($clientContext.GetActionByName($form, "GetCodeCoverage"))

            $CCResultControl = $clientContext.GetControlByName($form, "CCResultsCSVText")
            $CCInfoControl = $clientContext.GetControlByName($form, "CCInfo")
            $CCResult = $CCResultControl.StringValue
            $CCInfo = $CCInfoControl.StringValue
            if($CCInfo -ne $script:CCCollectedResult){
                $CCInfo = $CCInfo -replace ",","-"
                $CCOutputFilename = $CodeCoverageFilePrefix +"_$CCInfo.dat"
                Write-Host "Storing coverage results of $CCCodeunitId in:  $OutputPath\$CCOutputFilename"
                Set-Content -Path "$OutputPath\$CCOutputFilename" -Value $CCResult
            }
        } while ($CCInfo -ne $script:CCCollectedResult)
       
        if($ProduceCodeCoverageMap -ne 'Disabled') {
            $codeCoverageMapPath = Join-Path $OutputPath "TestCoverageMap"
            SaveCodeCoverageMap -OutputPath $codeCoverageMapPath  -DisableSSLVerification:$DisableSSLVerification -AutorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        }

        $clientContext.CloseForm($form)
    }
    finally{
        if($clientContext){
            $clientContext.Dispose()
        }
    }
}

function SaveCodeCoverageMap {
    param (
        [string] $OutputPath,
        [switch] $DisableSSLVerification,
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string] $AutorizationType = $script:DefaultAuthorizationType,
        [Parameter(Mandatory=$false)]
        [pscredential] $Credential,
        [Parameter(Mandatory=$true)]
        [string] $ServiceUrl
    )
    try{
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        $form = Open-TestForm -TestPage $TestPage -ClientContext $clientContext

        $clientContext.InvokeAction($clientContext.GetActionByName($form, "GetCodeCoverageMap"))

        $CCResultControl = $clientContext.GetControlByName($form, "CCMapCSVText")
        $CCMap = $CCResultControl.StringValue

        if (-not (Test-Path $OutputPath))
        {
            New-Item $OutputPath -ItemType Directory
        }
        
        $codeCoverageMapFileName = Join-Path $codeCoverageMapPath "TestCoverageMap.txt"
        if (-not (Test-Path $codeCoverageMapFileName))
        {
            New-Item $codeCoverageMapFileName -ItemType File
        }

        Add-Content -Path $codeCoverageMapFileName -Value $CCMap

        $clientContext.CloseForm($form)
    }
    finally{
        if($clientContext){
            $clientContext.Dispose()
        }
    }
}

function Get-Tests {
    Param(
        [ClientContext] $clientContext,
        [int] $testPage = 130409,
        [string] $testSuite = "DEFAULT",
        [string] $testCodeunit = "*",
        [string] $testCodeunitRange = "",
        [string] $extensionId = "",
        [string] $testRunnerCodeunitId = "",
        [array]  $disabledtests = @(),
        [switch] $debugMode,
        [switch] $ignoreGroups,
        [switch] $connectFromHost
    )

    if ($testPage -eq 130455) {
        $LineTypeAdjust = 1
    }
    else {
        $lineTypeAdjust = 0
        if ($disabledTests) {
            throw "Specifying disabledTests is not supported when using the C/AL test runner"
        }
        if ($extensionId) {
            throw "Specifying extensionId is not supported when using the C/AL test runner"
        }
        if ($testRunnerCodeunitId) {
            throw "Specifying testRunnerCodeunitId is not supported when using the C/AL test runner"
        }
    }

    if ($debugMode) {
        Write-Host "Get-Tests, open page $testpage"
    }

    $form = $clientContext.OpenForm($testPage)
    if (!($form)) {
        throw "Cannot open page $testPage. You might need to import the test toolkit and/or remove the folder $PSScriptRoot and retry. You might also have URL or Company name wrong."
    }
    if ($extensionId -ne "" -and $testSuite -ne "DEFAULT") {
        throw "You cannot specify testSuite and extensionId at the same time"
    }

    $suiteControl = $clientContext.GetControlByName($form, "CurrentSuiteName")
    $clientContext.SaveValue($suiteControl, $testSuite)

    if ($testPage -eq 130455) {
        Set-ExtensionId -ExtensionId $extensionId -Form $form -ClientContext $clientContext -debugMode:$debugMode
        Set-TestCodeunitRange -testCodeunitRange $testCodeunitRange -Form $form -ClientContext $clientContext -debugMode:$debugMode
        Set-TestRunnerCodeunitId -TestRunnerCodeunitId $testRunnerCodeunitId -Form $form -ClientContext $clientContext -debugMode:$debugMode
        Set-RunFalseOnDisabledTests -DisabledTests $DisabledTests -Form $form -ClientContext $clientContext -debugMode:$debugMode
        $clientContext.InvokeAction($clientContext.GetActionByName($form, 'ClearTestResults'))
    }

    $repeater = $clientContext.GetControlByType($form, [Microsoft.Dynamics.Framework.UI.Client.ClientRepeaterControl])
    $index = 0
    if ($testPage -eq 130455) {
        if ($debugMode) {
            Write-Host "Offset: $($repeater.offset)"
        }
        $clientContext.SelectFirstRow($repeater)
        $clientContext.Refresh($repeater)
        if ($debugMode) {
            Write-Host "Offset: $($repeater.offset)"
        }
    }

    $Tests = @()
    $group = $null
    while ($true)
    {
        $validationResults = $form.validationResults
        if ($validationResults) {
            throw "Validation errors occured. Error is: $($validationResults | ConvertTo-Json -Depth 99)"
        }

        if ($debugMode) {
            Write-Host "Index:  $index, Offset: $($repeater.Offset), Count:  $($repeater.DefaultViewport.Count)"
        }        
        if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
        {
            if ($debugMode) {
                Write-Host "Scroll"
            }
            $clientContext.ScrollRepeater($repeater, 1)
            if ($debugMode) {
                Write-Host "Index:  $index, Offset: $($repeater.Offset), Count:  $($repeater.DefaultViewport.Count)"
            }        
        }
        $rowIndex = $index - $repeater.Offset
        $index++
        if ($rowIndex -ge $repeater.DefaultViewport.Count)
        {
            if ($debugMode) {
                Write-Host "Breaking - rowIndex: $rowIndex"
            }
            break 
        }
        $row = $repeater.DefaultViewport[$rowIndex]
        $lineTypeControl = $clientContext.GetControlByName($row, "LineType")
        $lineType = "$(([int]$lineTypeControl.StringValue) + $lineTypeAdjust)"
        $name = $clientContext.GetControlByName($row, "Name").StringValue
        $codeUnitId = $clientContext.GetControlByName($row, "TestCodeunit").StringValue
        if ($testPage -eq 130455) {
            $run = $clientContext.GetControlByName($row, "Run").StringValue
        }
        else{
            $run = $true
        }

        if ($debugMode) {
            Write-Host "Row - lineType = $linetype, run = $run, CodeunitId = $codeUnitId, codeunitName = '$codeunitName', name = '$name'"
        }

        if ($name) {
            if ($linetype -eq "0" -and !$ignoreGroups) {
                $group = @{ "Group" = $name; "Codeunits" = @() }
                $Tests += $group
                            
            } elseif ($linetype -eq "1") {
                $codeUnitName = $name
                if ($codeunitId -like $testCodeunit -or $codeunitName -like $testCodeunit) {
                    if ($debugMode) { 
                        Write-Host "Initialize Codeunit"
                    }
                    $codeunit = @{ "Id" = "$codeunitId"; "Name" = $codeUnitName; "Tests" = @() }
                    if ($group) {
                        $group.Codeunits += $codeunit
                    }
                    else {
                        if ($run) {
                            if ($debugMode) { 
                                Write-Host "Add codeunit to tests"
                            }
                            $Tests += $codeunit
                        }
                    }
                }
            } elseif ($lineType -eq "2") {
                if ($codeunitId -like $testCodeunit -or $codeunitName -like $testCodeunit) {
                    if ($run) {
                        if ($debugMode) { 
                            Write-Host "Add test $name"
                        }
                        $codeunit.Tests += $name
                    }
                }
            }
        }
    }
    $clientContext.CloseForm($form)
    $Tests | ConvertTo-Json
}

function Run-ConnectionTest {
    Param(
        [ClientContext] $clientContext,
        [switch] $debugMode,
        [switch] $connectFromHost
    )

#    $rolecenter = $clientContext.OpenForm(9020)
#    if (!($rolecenter)) {
#        throw "Cannot open rolecenter"
#    }
#    Write-Host "Rolecenter 9020 opened successfully"

    $extensionManagement = $clientContext.OpenForm(2500)
    if (!($extensionManagement)) {
        throw "Cannnot open Extension Management page"
    }
    Write-Host "Extension Management opened successfully"

    $clientContext.CloseForm($extensionManagement)
    Write-Host "Extension Management successfully closed"
}

function GetDT {
    Param(
        $val
    )

    if ($val -is [DateTime]) {
        $val
    }
    else {
        [DateTime]::Parse($val)
    }
}

function Run-Tests {
    Param(
        [ClientContext] $clientContext,
        [int] $testPage = 130409,
        [string] $testSuite = "DEFAULT",
        [string] $testCodeunit = "*",
        [string] $testCodeunitRange = "",
        [string] $testGroup = "*",
        [string] $testFunction = "*",
        [string] $extensionId = "",
        [string] $testRunnerCodeunitId,
        [array]  $disabledtests = @(),
        [ValidateSet('Disabled', 'PerRun', 'PerCodeunit', 'PerTest')]
        [string] $CodeCoverageTrackingType = 'Disabled',
        [ValidateSet('Disabled','PerCodeunit','PerTest')]
        [string] $ProduceCodeCoverageMap = 'Disabled',
        [string] $CodeCoverageExporterId,
        [switch] $detailed,
        [switch] $debugMode,
        [string] $XUnitResultFileName = "",
        [switch] $AppendToXUnitResultFile,
        [string] $JUnitResultFileName = "",
        [switch] $AppendToJUnitResultFile,
        [switch] $ReRun,
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no',
        [ValidateSet('no','error','warning')]
        [string] $GitHubActions = 'no',
        [switch] $connectFromHost,
        [scriptblock] $renewClientContext
    )

    if ($testPage -eq 130455) {
        $LineTypeAdjust = 1
        $runSelectedName = "RunSelectedTests"
        $callStackName = "Stack Trace"
        $firstErrorName = "Error Message"
    }
    else {
        $lineTypeAdjust = 0
        $runSelectedName = "RunSelected"
        $callStackName = "Call Stack"
        $firstErrorName = "First Error"
        if ($disabledTests) {
            throw "Specifying disabledTests is not supported when using the C/AL test runner"
        }
        if ($extensionId) {
            throw "Specifying extensionId is not supported when using the C/AL test runner"
        }
        if ($testRunnerCodeunitId) {
            throw "Specifying testRunnerCodeunitId is not supported when using the C/AL test runner"
        }
    }
    $allPassed = $true
    $dumpAppsToTestOutput = $true

    if ($debugMode) {
        Write-Host "Run-Tests, open page $testpage"
    }

    $form = $clientContext.OpenForm($testPage)
    if (!($form)) {
        throw "Cannot open page $testPage. You might need to import the test toolkit to the container and/or remove the folder $PSScriptRoot and retry. You might also have URL or Company name wrong."
    }
    if ($extensionId -ne "" -and $testSuite -ne "DEFAULT") {
        throw "You cannot specify testSuite and extensionId at the same time"
    }

    $suiteControl = $clientContext.GetControlByName($form, "CurrentSuiteName")
    $clientContext.SaveValue($suiteControl, $testSuite)

    if ($testPage -eq 130455) {
        Set-ExtensionId -ExtensionId $extensionId -Form $form -ClientContext $clientContext -debugMode:$debugMode
        Set-TestCodeunitRange -testCodeunitRange $testCodeunitRange -Form $form -ClientContext $clientContext -debugMode:$debugMode
        Set-TestRunnerCodeunitId -TestRunnerCodeunitId $testRunnerCodeunitId -Form $form -ClientContext $clientContext -debugMode:$debugMode
        Set-RunFalseOnDisabledTests -DisabledTests $DisabledTests -Form $form -ClientContext $clientContext -debugMode:$debugMode
        $clientContext.InvokeAction($clientContext.GetActionByName($form, 'ClearTestResults'))
        if($CodeCoverageTrackingType -ne 'Disabled'){
            Set-CCTrackingType -Value $CodeCoverageTrackingType -Form $form -ClientContext $clientContext
            Set-CCExporterID -Value $CodeCoverageExporterId -Form $form -ClientContext $clientContext
            Clear-CCResults -Form $form -ClientContext $clientContext
            Set-CCProduceCodeCoverageMap -Value $ProduceCodeCoverageMap -Form $form -ClientContext $clientContext
        }
    }

    $process = $null
    if (!$connectFromHost) {
        $process = Get-Process -Name "Microsoft.Dynamics.Nav.Server" -ErrorAction SilentlyContinue
    }

    if ($XUnitResultFileName) {
        if (($Rerun -or $AppendToXUnitResultFile) -and (Test-Path $XUnitResultFileName)) {
            [xml]$XUnitDoc = [System.IO.File]::ReadAllLines($XUnitResultFileName)
            $XUnitAssemblies = $XUnitDoc.assemblies
            if (-not $XUnitAssemblies) {
                [xml]$XUnitDoc = New-Object System.Xml.XmlDocument
                $XUnitDoc.AppendChild($XUnitDoc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
                $XUnitAssemblies = $XUnitDoc.CreateElement("assemblies")
                $XUnitDoc.AppendChild($XUnitAssemblies) | Out-Null
            }
        }
        else {
            if (Test-Path $XUnitResultFileName -PathType Leaf) {
                Remove-Item $XUnitResultFileName -Force
            }
            [xml]$XUnitDoc = New-Object System.Xml.XmlDocument
            $XUnitDoc.AppendChild($XUnitDoc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
            $XUnitAssemblies = $XUnitDoc.CreateElement("assemblies")
            $XUnitDoc.AppendChild($XUnitAssemblies) | Out-Null
        }
    }
    if ($JUnitResultFileName) {
        if (($Rerun -or $AppendToJUnitResultFile) -and (Test-Path $JUnitResultFileName)) {
            [xml]$JUnitDoc = [System.IO.File]::ReadAllLines($JUnitResultFileName)

            $JUnitTestSuites = $JUnitDoc.testsuites
            if (-not $JUnitTestSuites) {
                [xml]$JUnitDoc = New-Object System.Xml.XmlDocument
                $JUnitDoc.AppendChild($JUnitDoc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
                $JUnitTestSuites = $JUnitDoc.CreateElement("testsuites")
                $JUnitDoc.AppendChild($JUnitTestSuites) | Out-Null
            }
        }
        else {
            if (Test-Path $JUnitResultFileName -PathType Leaf) {
                Remove-Item $JUnitResultFileName -Force
            }
            [xml]$JUnitDoc = New-Object System.Xml.XmlDocument
            $JUnitDoc.AppendChild($JUnitDoc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
            $JUnitTestSuites = $JUnitDoc.CreateElement("testsuites")
            $JUnitDoc.AppendChild($JUnitTestSuites) | Out-Null
        }
    }

    if ($testPage -eq 130455 -and $testCodeunit -eq "*" -and $testFunction -eq "*" -and $testGroup -eq "*" -and "$extensionId" -ne "") {

        if ($debugMode) {
            Write-Host "Using new test-runner mechanism"
        }

        $hostname = hostname

        while ($true) {
        
            if ($process) {
                $cimInstance = Get-CIMInstance Win32_OperatingSystem
                try { $cpu = "$($process.CPU.ToString("F3",[cultureinfo]::InvariantCulture))" } catch { $cpu = "n/a" }
                try { $mem = "$(($cimInstance.FreePhysicalMemory/1048576).ToString("F1",[CultureInfo]::InvariantCulture))" } catch { $mem = "n/a" }
                $processinfostart = "{ ""CPU"": ""$cpu"", ""Free Memory (Gb)"": ""$mem"" }"
            }
            $validationResults = $form.validationResults
            if ($validationResults) {
                throw "Validation errors occured. Error is: $($validationResults | ConvertTo-Json -Depth 99)"
            }
        
            if ($debugMode) {
                Write-Host "Invoke RunNextTest"
            }

            if ($renewClientContext) {
                $clientContext.CloseForm($form)
                $clientContext = Invoke-Command -ScriptBlock $renewClientContext
                $form = $clientContext.OpenForm($testPage)
            }

            $clientContext.InvokeAction($clientContext.GetActionByName($form, "RunNextTest"))
            $testResultControl = $clientContext.GetControlByName($form, "TestResultJson")
            $testResultJson = $testResultControl.StringValue

            if ($debugMode) {
                Write-Host "Result: '$testResultJson'"
            }

            if ($testResultJson -eq 'All tests executed.' -or $testResultJson -eq '') {
                break
            }
            $result = $testResultJson | ConvertFrom-Json
        
            Write-Host -NoNewline "  Codeunit $($result.codeUnit) $($result.name) "

            if ($XUnitResultFileName) {        
                if ($ReRun) {
                    $LastResult = $XUnitDoc.assemblies.ChildNodes | Where-Object { $_.name -eq "$($result.codeUnit) $($result.name)" }
                    if ($LastResult) {
                        $XUnitDoc.assemblies.RemoveChild($LastResult) | Out-Null
                    }
                }
                $XUnitAssembly = $XUnitDoc.CreateElement("assembly")
                $XUnitAssembly.SetAttribute("name","$($result.codeUnit) $($result.name)")
                $XUnitAssembly.SetAttribute("test-framework", "PS Test Runner")
                $XUnitAssembly.SetAttribute("run-date", (GetDT -val $result.startTime).ToString("yyyy-MM-dd"))
                $XUnitAssembly.SetAttribute("run-time", (GetDT -val $result.startTime).ToString("HH':'mm':'ss"))
                $XUnitAssembly.SetAttribute("total", $result.testResults.Count)
                $XUnitCollection = $XUnitDoc.CreateElement("collection")
                $XUnitAssembly.AppendChild($XUnitCollection) | Out-Null
                $XUnitCollection.SetAttribute("name", $result.name)
                $XUnitCollection.SetAttribute("total", $result.testResults.Count)
            }
            if ($JUnitResultFileName) {        
                if ($ReRun) {
                    $LastResult = $JUnitDoc.testsuites.ChildNodes | Where-Object { $_.name -eq "$($result.codeUnit) $($result.name)" }
                    if ($LastResult) {
                        $JUnitDoc.testsuites.RemoveChild($LastResult) | Out-Null
                    }
                }
                $JUnitTestSuite = $JUnitDoc.CreateElement("testsuite")
                $JUnitTestSuite.SetAttribute("name","$($result.codeUnit) $($result.name)")
                $JUnitTestSuite.SetAttribute("timestamp", (Get-Date -Format s))
                $JUnitTestSuite.SetAttribute("hostname", $hostname)

                $JUnitTestSuite.SetAttribute("time", 0)
                $JUnitTestSuite.SetAttribute("tests", $result.testResults.Count)

                $JunitTestSuiteProperties = $JUnitDoc.CreateElement("properties")
                $JUnitTestSuite.AppendChild($JunitTestSuiteProperties) | Out-Null

                if ($process) {
                    $property = $JUnitDoc.CreateElement("property")
                    $property.SetAttribute("name","processinfo.start")
                    $property.SetAttribute("value", $processinfostart)
                    $JunitTestSuiteProperties.AppendChild($property) | Out-Null

                    if ($extensionid) {
                        $property = $JUnitDoc.CreateElement("property")
                        $property.SetAttribute("name","extensionid")
                        $property.SetAttribute("value", $extensionId)
                        $JunitTestSuiteProperties.AppendChild($property) | Out-Null

                        $appname = "$(Get-NavAppInfo -ServerInstance $serverInstance | Where-Object { "$($_.AppId)" -eq $extensionId } | ForEach-Object { $_.Name })"
                        if ($appname) {
                            $property = $JUnitDoc.CreateElement("property")
                            $property.SetAttribute("name","appName")
                            $property.SetAttribute("value", $appName)
                            $JunitTestSuiteProperties.AppendChild($property) | Out-Null
                        }
                    }

                    if ($dumpAppsToTestOutput) {
                        $versionInfo = (Get-Item -Path "C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe").VersionInfo
                        $property = $JUnitDoc.CreateElement("property")
                        $property.SetAttribute("name", "platform.info")
                        $property.SetAttribute("value", "{ ""Version"": ""$($VersionInfo.ProductVersion)"" }")
                        $JunitTestSuiteProperties.AppendChild($property) | Out-Null
    
                        Get-NavAppInfo -ServerInstance $serverInstance | ForEach-Object {
                            $property = $JUnitDoc.CreateElement("property")
                            $property.SetAttribute("name", "app.info")
                            $property.SetAttribute("value", "{ ""Name"": ""$($_.Name)"", ""Publisher"": ""$($_.Publisher)"", ""Version"": ""$($_.Version)"" }")
                            $JunitTestSuiteProperties.AppendChild($property) | Out-Null
                        }
                        $dumpAppsToTestOutput = $false
                    }
                }
            }
        
            $totalduration = [Timespan]::Zero
            if ($result.PSobject.Properties.name -eq "testResults") {
                $result.testResults | ForEach-Object {
                    $testduration = (GetDT -val $_.finishTime).Subtract((GetDT -val $_.startTime))
                    if ($testduration.TotalSeconds -lt 0) { $testduration = [timespan]::Zero }
                    $totalduration += $testduration
                }
            }
        
            if ($result.result -eq "2") {
                Write-Host -ForegroundColor Green "Success ($([Math]::Round($totalduration.TotalSeconds,3)) seconds)"
            }
            elseif ($result.result -eq "1") {
                Write-Host -ForegroundColor Red "Failure ($([Math]::Round($totalduration.TotalSeconds,3)) seconds)"
                $allPassed = $false
            }
            else {
                Write-Host -ForegroundColor Yellow "Skipped"
            }
        
            $passed = 0
            $failed = 0
            $skipped = 0
        
            if ($result.PSobject.Properties.name -eq "testResults") {
                $result.testResults | ForEach-Object {
                    $testduration = (GetDT -val $_.finishTime).Subtract((GetDT -val $_.startTime))
                    if ($testduration.TotalSeconds -lt 0) { $testduration = [timespan]::Zero }
        
                    if ($XUnitResultFileName) {
                        if ($XUnitAssembly.ParentNode -eq $null) {
                            $XUnitAssemblies.AppendChild($XUnitAssembly) | Out-Null
                        }
            
                        $XUnitTest = $XUnitDoc.CreateElement("test")
                        $XUnitCollection.AppendChild($XUnitTest) | Out-Null
                        $XUnitTest.SetAttribute("name", $XUnitCollection.GetAttribute("name")+':'+$_.method)
                        $XUnitTest.SetAttribute("method", $_.method)
                        $XUnitTest.SetAttribute("time", [Math]::Round($testduration.TotalSeconds,3).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                    }
                    if ($JUnitResultFileName) {
                        if ($JUnitTestSuite.ParentNode -eq $null) {
                            $JUnitTestSuites.AppendChild($JUnitTestSuite) | Out-Null
                        }
            
                        $JUnitTestCase = $JUnitDoc.CreateElement("testcase")
                        $JUnitTestSuite.AppendChild($JUnitTestCase) | Out-Null
                        $JUnitTestCase.SetAttribute("classname", $JUnitTestSuite.GetAttribute("name"))
                        $JUnitTestCase.SetAttribute("name", $_.method)
                        $JUnitTestCase.SetAttribute("time", [Math]::Round($testduration.TotalSeconds,3).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                    }
                    if ($_.result -eq 2) {
                        if ($detailed) {
                            Write-Host -ForegroundColor Green "    Testfunction $($_.method) Success ($([Math]::Round($testduration.TotalSeconds,3)) seconds)"
                        }
                        if ($XUnitResultFileName) {
                            $XUnitTest.SetAttribute("result", "Pass")
                        }
                        $passed++
                    }
                    elseif ($_.result -eq 1) {
                        $stacktrace = $_.stacktrace
                        if ($stacktrace.EndsWith(';')) {
                            $stacktrace = $stacktrace.Substring(0,$stacktrace.Length-1)
                        }
                        if ($AzureDevOps -ne 'no') {
                            Write-Host "##vso[task.logissue type=$AzureDevOps;sourcepath=$($_.method);]$($_.message)"
                        }
                        if ($GitHubActions -ne 'no') {
                            Write-Host "::$($GitHubActions)::Function $($_.method) $($_.message)"
                        }
                        Write-Host -ForegroundColor Red "    Testfunction $($_.method) Failure ($([Math]::Round($testduration.TotalSeconds,3)) seconds)"
                        if ($XUnitResultFileName) {
                            $XUnitTest.SetAttribute("result", "Fail")
                        }
                        $failed++
            
                        if ($detailed) {
                            Write-Host -ForegroundColor Red "      Error:"
                            Write-Host -ForegroundColor Red "        $($_.message)"
                            Write-Host -ForegroundColor Red "      Call Stack:"
                            Write-Host -ForegroundColor Red "        $($stacktrace.Replace(";","`n        "))"
                        }
            
                        if ($XUnitResultFileName) {
                            $XUnitFailure = $XUnitDoc.CreateElement("failure")
                            $XUnitMessage = $XUnitDoc.CreateElement("message")
                            $XUnitMessage.InnerText = $_.message
                            $XUnitFailure.AppendChild($XUnitMessage) | Out-Null
                            $XUnitStacktrace = $XUnitDoc.CreateElement("stack-trace")
                            $XUnitStacktrace.InnerText = $_.stacktrace.Replace(";","`n")
                            $XUnitFailure.AppendChild($XUnitStacktrace) | Out-Null
                            $XUnitTest.AppendChild($XUnitFailure) | Out-Null
                        }
                        if ($JUnitResultFileName) {
                            $JUnitFailure = $JUnitDoc.CreateElement("failure")
                            $JUnitFailure.SetAttribute("message", $_.message)
                            $JUnitFailure.InnerText = $_.stacktrace.Replace(";","`n")
                            $JUnitTestCase.AppendChild($JUnitFailure) | Out-Null
                        }
                    }
                    else {
                        if ($detailed) {
                            Write-Host -ForegroundColor Yellow "    Testfunction $($_.method) Skipped"
                        }
            
                        if ($XUnitResultFileName) {
                            $XUnitTest.SetAttribute("result", "Skip")
                        }
                        if ($JUnitResultFileName) {
                            $JUnitSkipped = $JUnitDoc.CreateElement("skipped")
                            $JUnitTestCase.AppendChild($JUnitSkipped) | Out-Null
                        }
                        $skipped++
                    }
                }
            }
        
            if ($XUnitResultFileName) {
                $XUnitAssembly.SetAttribute("passed", $Passed)
                $XUnitAssembly.SetAttribute("failed", $failed)
                $XUnitAssembly.SetAttribute("skipped", $skipped)
                $XUnitAssembly.SetAttribute("time", [Math]::Round($totalduration.TotalSeconds,3).ToString([System.Globalization.CultureInfo]::InvariantCulture))
        
                $XUnitCollection.SetAttribute("passed", $Passed)
                $XUnitCollection.SetAttribute("failed", $failed)
                $XUnitCollection.SetAttribute("skipped", $skipped)
                $XUnitCollection.SetAttribute("time", [Math]::Round($totalduration.TotalSeconds,3).ToString([System.Globalization.CultureInfo]::InvariantCulture))
            }
            if ($JUnitResultFileName) {
                $JUnitTestSuite.SetAttribute("errors", 0)
                $JUnitTestSuite.SetAttribute("failures", $failed)
                $JUnitTestSuite.SetAttribute("skipped", $skipped)
                $JUnitTestSuite.SetAttribute("time", [Math]::Round($totalduration.TotalSeconds,3).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                if ($process) {
                    $cimInstance = Get-CIMInstance Win32_OperatingSystem
                    $property = $JUnitDoc.CreateElement("property")
                    $property.SetAttribute("name","processinfo.end")
                    try { $cpu = "$($process.CPU.ToString("F3",[CultureInfo]::InvariantCulture))" } catch { $cpu = "n/a" }
                    try { $mem = "$(($cimInstance.FreePhysicalMemory/1048576).ToString("F1",[CultureInfo]::InvariantCulture))" } catch { $mem = "n/a" }
                    $property.SetAttribute("value", "{ ""CPU"": ""$cpu"", ""Free Memory (Gb)"": ""$mem"" }")
                    $JunitTestSuiteProperties.AppendChild($property) | Out-Null
                }
            }
        }

    }
    else {

        if ($debugMode -and $testpage -eq 130455) {
            Write-Host "Using repeater based test-runner"
        }

        $hostname = hostname

        $filterControl = $clientContext.GetControlByType($form, [Microsoft.Dynamics.Framework.UI.Client.ClientFilterLogicalControl])
        $repeater = $clientContext.GetControlByType($form, [Microsoft.Dynamics.Framework.UI.Client.ClientRepeaterControl])
        $index = 0
        if ($testPage -eq 130455) {
            if ($debugMode) {
                Write-Host "Offset: $($repeater.offset)"
            }
            $clientContext.SelectFirstRow($repeater)
            $clientContext.Refresh($repeater)
            if ($debugMode) {
                Write-Host "Offset: $($repeater.offset)"
            }
        }

        $i = 0
        if ([int]::TryParse($testCodeunit, [ref] $i) -and ($testCodeunit -eq $i)) {
            if (([System.Management.Automation.PSTypeName]'Microsoft.Dynamics.Framework.UI.Client.Interactions.ExecuteFilterInteraction').Type) {
                $filterInteraction = New-Object Microsoft.Dynamics.Framework.UI.Client.Interactions.ExecuteFilterInteraction -ArgumentList $filterControl
                $filterInteraction.QuickFilterColumnId = $filterControl.QuickFilterColumns[0].Id
                $filterInteraction.QuickFilterValue = $testCodeunit
                $clientContext.InvokeInteraction($filterInteraction)
            }
            else {
                $filterInteraction = New-Object Microsoft.Dynamics.Framework.UI.Client.Interactions.FilterInteraction -ArgumentList $filterControl
                $filterInteraction.FilterColumnId = $filterControl.FilterColumns[0].Id
                $filterInteraction.FilterValue = $testCodeunit
                $clientContext.InvokeInteraction($filterInteraction)
                if ($testPage -eq 130455) {
                    $clientContext.SelectFirstRow($repeater)
                    $clientContext.Refresh($repeater)
                }
            }
        }
    
        $codeunitName = ""
        $codeunitNames = @{}
        $LastCodeunitName = ""
        $groupName = ""
    
        while ($true)
        {
    
            $validationResults = $form.validationResults
            if ($validationResults) {
                throw "Validation errors occured. Error is: $($validationResults | ConvertTo-Json -Depth 99)"
            }
    
            do {
    
                if ($debugMode) {
                    Write-Host "Index:  $index, Offset: $($repeater.Offset), Count:  $($repeater.DefaultViewport.Count)"
                }        
    
                if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
                {
                    if ($debugMode) {
                        Write-Host "Scroll"
                    }
                    $clientContext.ScrollRepeater($repeater, 1)
                    if ($debugMode) {
                        Write-Host "Index:  $index, Offset: $($repeater.Offset), Count:  $($repeater.DefaultViewport.Count)"
                    }        
                }
                $rowIndex = $index - $repeater.Offset
                $index++
                if ($rowIndex -ge $repeater.DefaultViewport.Count)
                {
                    if ($debugMode) {
                        Write-Host "Breaking - rowIndex: $rowIndex"
                    }
                    break
                }
                $row = $repeater.DefaultViewport[$rowIndex]
                $lineTypeControl = $clientContext.GetControlByName($row, "LineType")
                $lineType = "$(([int]$lineTypeControl.StringValue) + $lineTypeAdjust)"
                $name = $clientContext.GetControlByName($row, "Name").StringValue
                $codeUnitId = $clientContext.GetControlByName($row, "TestCodeunit").StringValue
                if ($testPage -eq 130455) {
                    $run = $clientContext.GetControlByName($row, "Run").StringValue
                }
                else{
                    $run = $true
                }

                if ($debugMode) {
                    Write-Host "Row - lineType = $linetype, run = $run, CodeunitId = $codeUnitId, codeunitName = '$codeunitName', name = '$name'"
                }
    
                if ($name) {
                    if ($linetype -eq "0") {
                        $groupName = $name
                    }
                    elseif ($linetype -eq "1") {
                        $codeUnitName = $name
                        if (!($codeUnitNames.Contains($codeunitId))) {
                            $codeUnitNames += @{ $codeunitId = $codeunitName }
                        }
                    }
                    elseif ($linetype -eq "2") {
                        $codeUnitname = $codeUnitNames[$codeunitId]
                    }
                }
            } while (!(($codeunitId -like $testCodeunit -or $codeunitName -like $testCodeunit) -and ($linetype -eq "1" -or $name -like $testFunction)))
    
            if ($debugMode) {
                Write-Host "Found Row - index = $index, rowIndex = $($rowIndex)/$($repeater.DefaultViewport.Count), lineType = $linetype, run = $run, CodeunitId = $codeUnitId, codeunitName = '$codeunitName', name = '$name'"
            }
    
            if ($rowIndex -ge $repeater.DefaultViewport.Count -or !($name))
            {
                break 
            }
    
            if ($groupName -like $testGroup) {
                switch ($linetype) {
                    "1" {
                        $startTime = get-date
                        $totalduration = [Timespan]::Zero

                        if ($TestFunction -eq "*") {
                            Write-Host "  Codeunit $codeunitId $name " -NoNewline

                            $prevoffset = $repeater.Offset

                            if ($testPage -eq 130455 -and $testCodeunit -eq "*") {
                                $filterInteraction = New-Object Microsoft.Dynamics.Framework.UI.Client.Interactions.FilterInteraction -ArgumentList $filterControl
                                $filterInteraction.FilterColumnId = $filterControl.FilterColumns[0].Id
                                $filterInteraction.FilterValue = $codeUnitId
                                $clientContext.InvokeInteraction($filterInteraction)
                                $clientContext.SelectFirstRow($repeater)
                                $clientContext.Refresh($repeater)
                            }
                            else {
                                $clientContext.ActivateControl($lineTypeControl)
                            }

                            $clientContext.InvokeAction($clientContext.GetActionByName($form, $runSelectedName))
            
                            if ($testPage -eq 130455) {
                                if ($testCodeunit -eq "*") {
                                    $filterInteraction = New-Object Microsoft.Dynamics.Framework.UI.Client.Interactions.FilterInteraction -ArgumentList $filterControl
                                    $filterInteraction.FilterColumnId = $filterControl.FilterColumns[0].Id
                                    $filterInteraction.FilterValue = ''
                                    $clientContext.InvokeInteraction($filterInteraction)
                                }
                                $clientContext.SelectFirstRow($repeater)
                                $clientContext.Refresh($repeater)
                            
                                while ($repeater.Offset -lt $prevoffset) {
                                    $clientContext.ScrollRepeater($repeater, 1)
                                }
                                $row = $repeater.DefaultViewport[$rowIndex]
                            }
                            else {
                                $row = $repeater.CurrentRow
                                if ($repeater.DefaultViewport[0].Bookmark -eq $row.Bookmark) {
                                    $index = $repeater.Offset+1
                                }
                            }

                            $finishTime = get-date
                            $duration = $finishTime.Subtract($startTime)
    
                            $result = $clientContext.GetControlByName($row, "Result").StringValue
                            if ($result -eq "2") {
                                Write-Host -ForegroundColor Green "Success ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                            }
                            elseif ($result -eq "3") {
                                Write-Host -ForegroundColor Yellow "Skipped"
                            }
                            else {
                                Write-Host -ForegroundColor Red "Failure ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                                $allPassed = $false
                            }
                        }
                        if ($XUnitResultFileName) {
                            if ($ReRun) {
                                $LastResult = $XUnitDoc.assemblies.ChildNodes | Where-Object { $_.name -eq "$codeunitId $Name" }
                                if ($LastResult) {
                                    $XUnitDoc.assemblies.RemoveChild($LastResult) | Out-Null
                                }
                            }
                            $XUnitAssembly = $XUnitDoc.CreateElement("assembly")
                            $XUnitAssembly.SetAttribute("name","$codeunitId $Name")
                            $XUnitAssembly.SetAttribute("test-framework", "PS Test Runner")
                            $XUnitAssembly.SetAttribute("run-date", $startTime.ToString("yyyy-MM-dd"))
                            $XUnitAssembly.SetAttribute("run-time", $startTime.ToString("HH':'mm':'ss"))
                            $XUnitAssembly.SetAttribute("total",0)
                            $XUnitAssembly.SetAttribute("passed",0)
                            $XUnitAssembly.SetAttribute("failed",0)
                            $XUnitAssembly.SetAttribute("skipped",0)
                            $XUnitAssembly.SetAttribute("time", "0")
                            $XUnitCollection = $XUnitDoc.CreateElement("collection")
                            $XUnitAssembly.AppendChild($XUnitCollection) | Out-Null
                            $XUnitCollection.SetAttribute("name","$Name")
                            $XUnitCollection.SetAttribute("total",0)
                            $XUnitCollection.SetAttribute("passed",0)
                            $XUnitCollection.SetAttribute("failed",0)
                            $XUnitCollection.SetAttribute("skipped",0)
                            $XUnitCollection.SetAttribute("time", "0")
                        }
                        if ($JUnitResultFileName) {
                            if ($ReRun) {
                                $LastResult = $JUnitDoc.testsuites.ChildNodes | Where-Object { $_.name -eq "$codeunitId $Name" }
                                if ($LastResult) {
                                    $JUnitDoc.testsuites.RemoveChild($LastResult) | Out-Null
                                }
                            }
                            $JUnitTestSuite = $JUnitDoc.CreateElement("testsuite")
                            $JUnitTestSuite.SetAttribute("name","$codeunitId $Name")
                            $JUnitTestSuite.SetAttribute("timestamp", (Get-Date -Format s))
                            $JUnitTestSuite.SetAttribute("hostname", $hostname)
                            $JUnitTestSuite.SetAttribute("time", 0)
                            $JUnitTestSuite.SetAttribute("tests", 0)
                            $JUnitTestSuite.SetAttribute("failures", 0)
                            $JUnitTestSuite.SetAttribute("errors", 0)
                            $JUnitTestSuite.SetAttribute("skipped", 0)
                        }
                    }
                    "2" {
                        if ($testFunction -ne "*") {
                            if ($LastCodeunitName -ne $codeunitName) {
                                Write-Host "Codeunit $CodeunitId $CodeunitName"
                                $LastCodeunitName = $CodeUnitname
                            }
                            $clientContext.ActivateControl($lineTypeControl)

                            $startTime = get-date
                            $clientContext.InvokeAction($clientContext.GetActionByName($form, $runSelectedName))
                            $finishTime = get-date
                            $testduration = $finishTime.Subtract($startTime)
                            if ($testduration.TotalSeconds -lt 0) { $testduration = [timespan]::Zero }

                            $row = $repeater.CurrentRow
                            for ($idx = 0; $idx -lt $repeater.DefaultViewPort.Count; $idx++) {
                                if ($repeater.DefaultViewPort[$idx].Bookmark -eq $row.Bookmark) {
                                    $index = $repeater.Offset+$idx+1
                                }
                            }
                        }
                        $result = $clientContext.GetControlByName($row, "Result").StringValue
                        $startTime = $clientContext.GetControlByName($row, "Start Time").ObjectValue
                        $finishTime = $clientContext.GetControlByName($row, "Finish Time").ObjectValue
                        $testduration = $finishTime.Subtract($startTime)
                        if ($testduration.TotalSeconds -lt 0) { $testduration = [timespan]::Zero }
                        $totalduration += $testduration
                        if ($XUnitResultFileName) {
                            if ($XUnitAssembly.ParentNode -eq $null) {
                                $XUnitAssemblies.AppendChild($XUnitAssembly) | Out-Null
                            }
                            $XUnitAssembly.SetAttribute("time",([Math]::Round($totalduration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                            $XUnitAssembly.SetAttribute("total",([int]$XUnitAssembly.GetAttribute("total")+1))
                            $XUnitTest = $XUnitDoc.CreateElement("test")
                            $XUnitCollection.AppendChild($XUnitTest) | Out-Null
                            $XUnitTest.SetAttribute("name", $XUnitCollection.GetAttribute("name")+':'+$Name)
                            $XUnitTest.SetAttribute("method", $Name)
                            $XUnitTest.SetAttribute("time", ([Math]::Round($testduration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                        }
                        if ($JUnitResultFileName) {
                            if ($JUnitTestSuite.ParentNode -eq $null) {
                                $JUnitTestSuites.AppendChild($JUnitTestSuite) | Out-Null
                            }
                            $JUnitTestSuite.SetAttribute("time",([Math]::Round($totalduration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                            $JUnitTestSuite.SetAttribute("total",([int]$JUnitTestSuite.GetAttribute("total")+1))
                            $JUnitTestCase = $JUnitDoc.CreateElement("testcase")
                            $JUnitTestSuite.AppendChild($JUnitTestCase) | Out-Null
                            $JUnitTestCase.SetAttribute("classname", $JUnitTestSuite.GetAttribute("name"))
                            $JUnitTestCase.SetAttribute("name", $Name)
                            $JUnitTestCase.SetAttribute("time", ([Math]::Round($testduration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                        }
                        if ($result -eq "2") {
                            if ($detailed) {
                                Write-Host -ForegroundColor Green "    Testfunction $name Success ($([Math]::Round($testduration.TotalSeconds,3)) seconds)"
                            }
                            if ($XUnitResultFileName) {
                                $XUnitAssembly.SetAttribute("passed",([int]$XUnitAssembly.GetAttribute("passed")+1))
                                $XUnitTest.SetAttribute("result", "Pass")
                            }
                        }
                        elseif ($result -eq "1") {
                            $firstError = $clientContext.GetControlByName($row, $firstErrorName).StringValue
                            $callStack = $clientContext.GetControlByName($row, $callStackName).StringValue
                            if ($callStack.EndsWith("\")) { $callStack = $callStack.Substring(0,$callStack.Length-1) }
                            if ($AzureDevOps -ne 'no') {
                                Write-Host "##vso[task.logissue type=$AzureDevOps;sourcepath=$name;]$firstError"
                            }
                            if ($GitHubActions -ne 'no') {
                                Write-Host "::$($GitHubActions)::Function $name $firstError"
                            }
                            Write-Host -ForegroundColor Red "    Testfunction $name Failure ($([Math]::Round($testduration.TotalSeconds,3)) seconds)"
                            $allPassed = $false
                            if ($XUnitResultFileName) {
                                $XUnitAssembly.SetAttribute("failed",([int]$XUnitAssembly.GetAttribute("failed")+1))
                                $XUnitTest.SetAttribute("result", "Fail")
                                $XUnitFailure = $XUnitDoc.CreateElement("failure")
                                $XUnitMessage = $XUnitDoc.CreateElement("message")
                                $XUnitMessage.InnerText = $firstError
                                $XUnitFailure.AppendChild($XUnitMessage) | Out-Null
                                $XUnitStacktrace = $XUnitDoc.CreateElement("stack-trace")
                                $XUnitStacktrace.InnerText = $Callstack.Replace("\","`n")
                                $XUnitFailure.AppendChild($XUnitStacktrace) | Out-Null
                                $XUnitTest.AppendChild($XUnitFailure) | Out-Null
                            }
                            if ($JUnitResultFileName) {
                                $JUnitTestSuite.SetAttribute("failures",([int]$JUnitTestSuite.GetAttribute("failures")+1))
                                $JUnitTestCase.SetAttribute("result", "Fail")
                                $JUnitFailure = $JUnitDoc.CreateElement("failure")
                                $JUnitFailure.SetAttribute("message", $firstError)
                                $JUnitFailure.InnerText = $Callstack.Replace("\","`n")
                                $JUnitTestCase.AppendChild($JUnitFailure) | Out-Null
                            }
                        }
                        else {
                            if ($detailed) {
                                Write-Host -ForegroundColor Yellow "    Testfunction $name Skipped"
                            }
                            if ($XUnitResultFileName) {
                                $XUnitCollection.SetAttribute("skipped",([int]$XUnitCollection.GetAttribute("skipped")+1))
                                $XUnitAssembly.SetAttribute("skipped",([int]$XUnitAssembly.GetAttribute("skipped")+1))
                                $XUnitTest.SetAttribute("result", "Skip")
                            }
                            if ($JUnitResultFileName) {
                                $JUnitTestSuite.SetAttribute("skipped",([int]$JUnitTestSuite.GetAttribute("skipped")+1))
                                $JUnitSkipped = $JUnitDoc.CreateElement("skipped")
                                $JUnitTestCase.AppendChild($JUnitSkipped) | Out-Null
                            }
                        }
                        if ($result -eq "1" -and $detailed) {
                            Write-Host -ForegroundColor Red "      Error:"
                            Write-Host -ForegroundColor Red "        $firstError"
                            Write-Host -ForegroundColor Red "      Call Stack:"
                            Write-Host -ForegroundColor Red "        $($callStack.Replace('\',"`n        "))"
                        }
                        if ($XUnitResultFileName) {
                            $XUnitCollection.SetAttribute("time", $XUnitAssembly.GetAttribute("time"))
                            $XUnitCollection.SetAttribute("total", $XUnitAssembly.GetAttribute("total"))
                            $XUnitCollection.SetAttribute("passed", $XUnitAssembly.GetAttribute("passed"))
                            $XUnitCollection.SetAttribute("failed", $XUnitAssembly.GetAttribute("failed"))
                            $XUnitCollection.SetAttribute("Skipped", $XUnitAssembly.GetAttribute("skipped"))
                        }
                    }
                    else {
                    }
                }
            }
        }
    }
    if ($XUnitResultFileName) {
        $XUnitDoc.Save($XUnitResultFileName)
    }
    if ($JUnitResultFileName) {
        $JUnitDoc.Save($JUnitResultFileName)
    }
    $clientContext.CloseForm($form)
    $allPassed
}

function Disable-SslVerification
{
    if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
$sslCallbackCode = @"
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;

    public static class SslVerification
    {
        public static bool DisabledServerCertificateValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
        public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = DisabledServerCertificateValidationCallback; }
        public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
    }
"@
        Add-Type -TypeDefinition $sslCallbackCode
    }
    [SslVerification]::Disable()
}

function Enable-SslVerification
{
    if (([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
        [SslVerification]::Enable()
    }
}

function Set-TcpKeepAlive {
    Param(
        [Duration] $tcpKeepAlive
    )

    # Set Keep-Alive on Tcp Level to 1 minute to avoid Azure closing our connection
    [System.Net.ServicePointManager]::SetTcpKeepAlive($true, [int]$tcpKeepAlive.TotalMilliseconds, [int]$tcpKeepAlive.TotalMilliseconds)
}
