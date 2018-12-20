<#
 .Synopsis
  Convert Output from CAL Test Runner to XUnit format, compatible with Azure DevOps
 .Description
  Test errors will also be displayed as build warnings or build errors in the Build pipeline
 .Parameter TestXml
  Output from CAL Test Runner XML Port 130403 CAL Export Test Result
 .Example
  (Get-Content -Path "c:\temp\CALTestResults.xml" -Raw | Convert-CALTestOutputToAzureDevOps).Save("c:\temp\TestResult.xml")
#>
function Convert-CALTestOutputToAzureDevOps {
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [xml] $TestXml,
        [switch] $FailOnTestError
    )

    #$TestXml = [xml]$content
    [xml]$Doc = New-Object System.Xml.XmlDocument
    $doc.AppendChild($Doc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
    $assemblies = $doc.CreateElement("assemblies")
    $doc.AppendChild($assemblies) | Out-Null
    $TestXml.TestResults.TestResult | Group-Object -Property CUName | % {
        $assembly = $doc.CreateElement("assembly")
        $assembly.SetAttribute("name",$_.Name)
        $assembly.SetAttribute("test-framework", "CAL Test Runner")
        $assembly.SetAttribute("run-date", (get-date).ToString("yyyy-MM-dd"))
        $assembly.SetAttribute("run-time", (get-date).ToString("HH:mm:ss"))
        $assemblies.AppendChild($assembly) | Out-Null
    
        #<collection total="9" passed="9" failed="0" skipped="0" name="Codeunit 11" time="0.094">
    
        $collection = $doc.CreateElement("collection")
    
        $pass = 0
        $fail = 0
    
        $total = New-Object System.TimeSpan
        $_.Group | ForEach-Object { 
            $test = $doc.CreateElement("test")
            $test.SetAttribute("name", $_.FName)
            $test.SetAttribute("method", $_.FName)
            $time = Convert-CALExecutionTimeToTimeSpan -CALExecutionTime $_.ExecutionTime
            $test.SetAttribute("time", $time.TotalSeconds.ToString([System.Globalization.CultureInfo]::InvariantCulture))
            if ($_.Result -eq "Passed") {
                $test.SetAttribute("result", "Pass")
                $pass++
            } else {
                $test.SetAttribute("result", "Fail")
                $failure = $doc.CreateElement("failure")
                $message = $doc.CreateElement("message")
                $message.InnerText = $_.ErrorMessage
                $failure.AppendChild($message) | Out-Null
                $stacktrace = $doc.CreateElement("stack-trace")
                $stacktrace.InnerText = $_.Callstack.Replace("\","
")
                $failure.AppendChild($stacktrace) | Out-Null
                $test.AppendChild($failure) | Out-Null
                $fail++
                if ($FailOnTestError) {
                    Write-Host "##vso[task.logissue type=error;sourcepath=$($_.FName);]$($_.ErrorMessage)"
                } else {
                    Write-Host "##vso[task.logissue type=warning;sourcepath=$($_.FName);]$($_.ErrorMessage)"
                }
            }
            $collection.AppendChild($test) | Out-Null
            $total += $time
        }
        $collection.SetAttribute("time", $total.TotalSeconds.ToString([System.Globalization.CultureInfo]::InvariantCulture))
        $collection.SetAttribute("total",($pass+$fail))
        $collection.SetAttribute("passed",$pass)
        $collection.SetAttribute("failed",$fail)
        $assembly.SetAttribute("total",($pass+$fail))
        $assembly.SetAttribute("passed",$pass)
        $assembly.SetAttribute("failed",$fail)
        $assembly.SetAttribute("time", $total.TotalSeconds.ToString([System.Globalization.CultureInfo]::InvariantCulture))
        $assembly.AppendChild($collection) | Out-Null
    }
    $doc
}
Export-ModuleMember Convert-CALTestOutputToAzureDevOps
