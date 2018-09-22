<#
 .Synopsis
  Convert ExectionTime from CAL Test Runner output to System.Duraction
 .Description
  This function converts a string containing a CAL Test Runner ExecutionTime string in english to a System.Duration value
 .Parameter CALExecutionTime
  Execution time string in english as exported in the ExportTestResult XMLPort
 .Example
  Convert-CALExecutionTime -CALExecutionTime "2 minutes 1 second 65 milliseconds"
#>
function Convert-CALExecutionTimeToTimeSpan {
    Param( 
        [string] $CALExecutionTime
    ) 

    $CALExecutionTime = $CALExecutionTime -replace 'hour','/' -replace 'minute',':' -replace 'millisecond', ';' -replace 'second','.' -replace '[^.-;]'
    if (!$CALExecutionTime.Contains('/')) {
        $CALExecutionTime = "0/" + $CALExecutionTime
    }
    if (!$CALExecutionTime.Contains(':')) {
        $idx = $CALExecutionTime.IndexOf('/')
        $CALExecutionTime = $CALExecutionTime.Substring(0,$idx+1) + "0:" + $CALExecutionTime.Substring($idx+1)
    }
    if (!$CALExecutionTime.Contains('.')) {
        $idx = $CALExecutionTime.IndexOf(':')
        $CALExecutionTime = $CALExecutionTime.Substring(0,$idx+1) + "0." + $CALExecutionTime.Substring($idx+1)
    }
    if (!$CALExecutionTime.Contains(';')) {
        $idx = $CALExecutionTime.IndexOf('.')
        $CALExecutionTime = $CALExecutionTime.Substring(0,$idx+1) + "0;" + $CALExecutionTime.Substring($idx+1)
    }
    $CALExecutionTime = $CALExecutionTime.Replace('/',':').Replace('.',':').Replace(';','')
    $a = $CALExecutionTime.Split(':')
    $l = "000"
    ($a.count-1)..0 | % {
        $a[$_] = ([int]::Parse($a[$_])).ToString($l)
        $l = "00"
    }
    [System.TimeSpan]::ParseExact([String]::Join(":", $a), "hh\:mm\:ss\:fff", $null)
}
Export-ModuleMember Convert-CALExecutionTimeToTimeSpan
