<#
 .Synopsis
  Convert Output from AL Compiler and output to host in Azure DevOps format
 .Description
  This function is a contribution from Microsoft MVP Kamil Sacek, read about it here:
  https://dynamicsuser.net/nav/b/kine/posts/alc-exe-output-formatting-for-tfs-vsts
 .Parameter AlcOutput
  One or more lines of outout from the AL Compiler
 .Parameter Failon
  Specify if you want the AzureDevOps output to fail on Error or Warning
 .Parameter DoNotWriteToHost
  Include this switch to return the converted result instead of outputting the result to the Host
 .Example
  Compile-AppInBcContainer -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Test" -AzureDevOps
 .Example
  & .\alc.exe /project:$appProjectFolder /packagecachepath:$appSymbolsFolder /out:$appOutputFile | Convert-AlcOutputToAzureDevOps
#>
Function Convert-AlcOutputToAzureDevOps {
    Param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $AlcOutput,
        [Parameter(Position=1)]
        [ValidateSet('none','error','warning')]
        [string] $FailOn,
        [switch] $doNotWriteToHost
    )

    Process {
        $hasError = $false
        $hasWarning = $false

        foreach($line in $AlcOutput) {
            switch -regex ($line) {
                "^warning (\w{2}\d{4}):(.*('.*').*|.*)$" {
                    if ($null -ne $Matches[3]) {
                        $newLine = "##vso[task.logissue type=warning;sourcepath=$($Matches[3]);code=$($Matches[1]);]$($Matches[2])"
                    } else {
                        $newLine = "##vso[task.logissue type=warning;code=$($Matches[1]);]$($Matches[2])"
                    }
            
                    $hasWarning = $true
                    break
                }
                "^(.*)\((\d+),(\d+)\): error (\w{2,3}\d{4}): (.*)$"
                #Objects\codeunit\Cod50130.name.al(62,30): error AL0118: The name '"Parent Object"' does not exist in the current context        
                {
                    $newLine = "##vso[task.logissue type=error;sourcepath=$($Matches[1]);linenumber=$($Matches[2]);columnnumber=$($Matches[3]);code=$($Matches[4]);]$($Matches[5])"
                    $hasError = $true
                    break
                }
                "^(.*)error (\w{2}\d{4}): (.*)$"
                #error AL0999: Internal error: System.AggregateException: One or more errors occurred. ---> System.InvalidOperationException
                {
                    $newLine = "##vso[task.logissue type=error;code=$($Matches[2]);]$($Matches[3])"
                    $hasError = $true
                    break
                }
                "^(.*)\((\d+),(\d+)\): warning (\w{2}\d{4}): (.*)$"
                #Prepared for unified warning format
                #Objects\codeunit\Cod50130.name.al(62,30): warning AL0118: The name '"Parent Object"' does not exist in the current context        
                {
                    $newLine = "##vso[task.logissue type=warning;sourcepath=$($Matches[1]);linenumber=$($Matches[2]);columnnumber=$($Matches[3]);code=$($Matches[4]);]$($Matches[5])"
                    $hasWarning = $true
                    break
                }
                default {
                    $newLine = $line
                    break
                }
            }
            if ($doNotWriteToHost) {
                $newLine
            }
            else {
                Write-Host $newLine
            }
        }

        $errLine = ""
        if (($FailOn -eq 'error' -and $hasError) -or ($FailOn -eq 'warning' -and ($hasError -or $hasWarning))) {
            $errLine = "##vso[task.complete result=Failed;]Failed."
        }
        elseif ($failOn -eq 'error' -and $hasWarning) {
            $errLine = "##vso[task.complete result=SucceededWithIssues;]Succeeded With Issues."
        }
        if ($errLine) {
            if ($doNotWriteToHost) {
                $errLine
            }
            else {
                Write-Host $errLine
            }
        }
    }
}
Export-ModuleMember -Function Convert-AlcOutputToAzureDevOps
