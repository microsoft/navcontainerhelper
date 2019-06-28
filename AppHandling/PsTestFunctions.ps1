Param(
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

. $clientContextScriptPath

function New-ClientContext {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $serviceUrl,
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string] $auth='NavUserPassword',
        [Parameter(Mandatory=$false)]
        [pscredential] $credential,
        [timespan] $transactionTimeout = [timespan]::FromMinutes(10),
        [string] $culture = "en-US"
    )

    if ($auth -eq "Windows") {
        return [ClientContext]::new($serviceUrl, $transactionTimeout, $culture)
    } elseif ($auth -eq "NavUserPassword") {
        if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
            throw "You need to specify credentials if using NavUserPassword authentication"
        }
        return [ClientContext]::new($serviceUrl, $credential, $transactionTimeout, $culture)
    } else {
        throw "Unsupported authentication setting"
    }
}

function Remove-ClientContext {
    Param(
        [ClientContext] $clientContext
    )
    if ($clientContext) {
        $clientContext.Dispose()
    }
}

function Get-Tests {
    Param(
        [ClientContext] $clientContext,
        [int] $testPage = 130409,
        [string] $testSuite = "DEFAULT",
        [string] $testCodeunit = "*"
    )

    $form = $clientContext.OpenForm($testPage)
    if (!($form)) {
        throw "Cannot open page $testPage. You might need to import the page object here: http://aka.ms/pstesttoolpagefob"
    }

    $suiteControl = $clientContext.GetControlByName($form, "CurrentSuiteName")
    $clientContext.SaveValue($suiteControl, $testSuite)
    
    $repeater = $clientContext.GetControlByType($form, [ClientRepeaterControl])
    $index = 0

    $Tests = @()
    $group = $null
    while ($true)
    {
        if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
        {
            $clientContext.ScrollRepeater($repeater, 1)
        }
        $rowIndex = $index - $repeater.Offset
        $index++
        if ($rowIndex -ge $repeater.DefaultViewport.Count)
        {
            break 
        }
        $row = $repeater.DefaultViewport[$rowIndex]
        $lineTypeControl = $clientContext.GetControlByName($row, "LineType")
        $lineType = $lineTypeControl.StringValue
        $name = $clientContext.GetControlByName($row, "Name").StringValue
        $codeUnitId = $clientContext.GetControlByName($row, "TestCodeunit").StringValue

        # Refresh form????
        #Write-Host "$linetype $name"        

        if ($linetype -eq "0") {
            $group = @{ "Group" = $name; "Codeunits" = @() }
            $Tests += $group
                        
        } elseif ($linetype -eq "1") {
            $codeUnitName = $name
            if ($codeunitId -like $testCodeunit -or $codeunitName -like $testCodeunit) {
                $codeunit = @{ "Id" = "$codeunitId"; "Name" = $codeUnitName; "Tests" = @() }
                if ($group) {
                    $group.Codeunits += $codeunit
                } else {
                    $Tests += $codeunit
                }
            }
        } elseif ($lineType -eq "2") {
            if ($codeunitId -like $testCodeunit -or $codeunitName -like $testCodeunit) {
                $codeunit.Tests += $name
            }
        }
    }
    $clientContext.CloseForm($form)
    $Tests | ConvertTo-Json
}

function Run-Tests {
    Param(
        [ClientContext] $clientContext,
        [int] $testPage = 130409,
        [string] $testSuite = "DEFAULT",
        [string] $testCodeunit = "*",
        [string] $testGroup = "*",
        [string] $testFunction = "*",
        [switch] $detailed,
        [string] $XUnitResultFileName = "",
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no'
    )

    $form = $clientContext.OpenForm($testPage)
    if (!($form)) {
        throw "Cannot open page $testPage. You might need to import the page object here: http://aka.ms/pstesttoolpagefob"
    }
    $suiteControl = $clientContext.GetControlByName($form, "CurrentSuiteName")
    $clientContext.SaveValue($suiteControl, $testSuite)
    $repeater = $clientContext.GetControlByType($form, [ClientRepeaterControl])
    $index = 0

    if ($XUnitResultFileName) {
        [xml]$XUnitDoc = New-Object System.Xml.XmlDocument
        $XUnitDoc.AppendChild($XUnitDoc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
        $XUnitAssemblies = $XUnitDoc.CreateElement("assemblies")
        $XUnitDoc.AppendChild($XUnitAssemblies) | Out-Null
    }
    
    $TestCodeunitNames = @{}
    $LastCodeunitName = ""
    $groupName = ""

    while ($true)
    {
        do {
            if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
            {
                $clientContext.ScrollRepeater($repeater, 1)
            }
            $rowIndex = $index - $repeater.Offset
            $index++
            if ($rowIndex -ge $repeater.DefaultViewport.Count)
            {
                break 
            }
            $row = $repeater.DefaultViewport[$rowIndex]
            $lineTypeControl = $clientContext.GetControlByName($row, "LineType")
            $lineType = $lineTypeControl.StringValue
            $name = $clientContext.GetControlByName($row, "Name").StringValue
            $codeUnitId = $clientContext.GetControlByName($row, "TestCodeunit").StringValue
            if ($linetype -eq "0") {
                $groupName = $name
            }
            elseif ($linetype -eq "1") {
                $codeUnitName = $name
                $codeUnitNames += @{ $codeunitId = $codeunitName }
            }
            elseif ($linetype -eq "2") {
                $codeUnitname = $codeUnitNames[$codeunitId]
            }
        } while (!(($codeunitId -like $testCodeunit -or $codeunitName -like $testCodeunit) -and ($linetype -eq "1" -or $name -like $testFunction)))

        if ($rowIndex -ge $repeater.DefaultViewport.Count)
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
                        $clientContext.ActivateControl($lineTypeControl)
        
                        $clientContext.InvokeAction($clientContext.GetActionByName($form, "RunSelected"))
                        $finishTime = get-date
                        $duration = $finishTime.Subtract($startTime)
        
                        $row = $repeater.CurrentRow
                        if ($repeater.DefaultViewport[0].Bookmark -eq $row.Bookmark) {
                            $index = $repeater.Offset+1
                        }
        
                        $result = $clientContext.GetControlByName($row, "Result").StringValue
                        if ($result -eq "2") {
                            Write-Host -ForegroundColor Green "Success ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                        }
                        else {
                            Write-Host -ForegroundColor Red "Failure ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                        }
                    }
                    if ($XUnitResultFileName) {
                        $XUnitAssembly = $XUnitDoc.CreateElement("assembly")
                        $XUnitAssembly.SetAttribute("name",$Name)
                        $XUnitAssembly.SetAttribute("test-framework", "PS Test Runner")
                        $XUnitAssembly.SetAttribute("run-date", $startTime.ToString("yyyy-MM-dd"))
                        $XUnitAssembly.SetAttribute("run-time", $startTime.ToString("HH:mm:ss"))
                        $XUnitAssembly.SetAttribute("total",0)
                        $XUnitAssembly.SetAttribute("passed",0)
                        $XUnitAssembly.SetAttribute("failed",0)
                        $XUnitAssembly.SetAttribute("time", "0")
                        $XUnitCollection = $XUnitDoc.CreateElement("collection")
                        $XUnitAssembly.AppendChild($XUnitCollection) | Out-Null
                        $XUnitCollection.SetAttribute("name",$Name)
                        $XUnitCollection.SetAttribute("total",0)
                        $XUnitCollection.SetAttribute("passed",0)
                        $XUnitCollection.SetAttribute("failed",0)
                        $XUnitCollection.SetAttribute("skipped",0)
                        $XUnitCollection.SetAttribute("time", "0")
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
                        $clientContext.InvokeAction($clientContext.GetActionByName($form, "RunSelected"))
                        $finishTime = get-date
                        $testduration = $finishTime.Subtract($startTime)
    
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
                    $totalduration += $testduration
                    if ($XUnitResultFileName) {
                        if ($XUnitAssembly.ParentNode -eq $null) {
                            $XUnitAssemblies.AppendChild($XUnitAssembly) | Out-Null
                        }
                        $XUnitAssembly.SetAttribute("time",([Math]::Round($totalduration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                        $XUnitAssembly.SetAttribute("total",([int]$XUnitAssembly.GetAttribute("total")+1))
                        $XUnitTest = $XUnitDoc.CreateElement("test")
                        $XUnitCollection.AppendChild($XUnitTest) | Out-Null
                        $XUnitTest.SetAttribute("name", $XUnitAssembly.GetAttribute("name")+':'+$Name)
                        $XUnitTest.SetAttribute("method", $Name)
                        $XUnitTest.SetAttribute("time", ([Math]::Round($testduration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
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
                        $firstError = $clientContext.GetControlByName($row, "First Error").StringValue
                        if ($AzureDevOps -ne 'no') {
                            Write-Host "##vso[task.logissue type=$AzureDevOps;sourcepath=$name;]$firstError"
                        }
                        Write-Host -ForegroundColor Red "    Testfunction $name Failure ($([Math]::Round($testduration.TotalSeconds,3)) seconds)"
                        $callStack = $clientContext.GetControlByName($row, "Call Stack").StringValue
                        if ($callStack.EndsWith("\")) { $callStack = $callStack.Substring(0,$callStack.Length-1) }
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
                    }
                    else {
                        if ($XUnitResultFileName) {
                            $XUnitCollection.SetAttribute("skipped",([int]$XUnitCollection.GetAttribute("skipped")+1))
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
                    }
                }
                else {
                }
            }
        }
    }
    if ($XUnitResultFileName) {
        $XUnitDoc.Save($XUnitResultFileName)
    }
    $clientContext.CloseForm($form)
}

function Disable-SslVerification
{
    if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
        Add-Type -TypeDefinition  @"
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class SslVerification
{
    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
    public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
    public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
}
"@
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
