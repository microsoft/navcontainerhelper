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
 .Parameter GitHubActions
  Include this switch, if you are running GitHub Actions
 .Parameter DoNotWriteToHost
  Include this switch to return the converted result instead of outputting the result to the Host
 .Parameter basePath
  Base Path of the files in the ALC output, to convert file paths to relative paths
 .Example
  Compile-AppInBcContainer -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Test" -AzureDevOps
 .Example
  Compile-AppInBcContainer -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Test" -GitHubActions
 .Example
  & .\alc.exe /project:$appProjectFolder /packagecachepath:$appSymbolsFolder /out:$appOutputFile | Convert-AlcOutputToAzureDevOps
#>
Function Convert-AlcOutputToDevOps {
    Param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        $AlcOutput,
        [Parameter(Position=1)]
        [ValidateSet('none','error','warning','newWarning')]
        [string] $FailOn,
        [switch] $gitHubActions = $bcContainerHelperConfig.IsGitHubActions,
        [switch] $doNotWriteToHost,
        [string] $basePath = ''
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    if ($basePath) {
        $basePath = "$($basePath.TrimEnd('\'))\"
    }
    $hasError = $false
    $hasWarning = $false

    foreach($line in $AlcOutput) {
        switch -regex ($line) {
            "^warning (\w{2,3}\d{4}):(.*('.*').*|.*)$" {
                if ($null -ne $Matches[3]) {
                    $file = $Matches[3]
                    if ($file -like "$($basePath)*") {
                        $file = ".\$($file.SubString($basePath.Length))".Replace('\','/')
                    }
                    if ($gitHubActions) {
                        $newLine = "::warning file=$($file)::code=$($Matches[1]) $($Matches[2])"
                    }
                    else {
                        $newLine = "##vso[task.logissue type=warning;sourcepath=$($file);$($Matches[1]);]$($Matches[2])"
                    }
                } else {
                    if ($gitHubActions) {
                        $newLine = "::warning::$($Matches[1]) $($Matches[2])"
                    }
                    else {
                        $newLine = "##vso[task.logissue type=warning;code=$($Matches[1]);]$($Matches[2])"
                    }
                }
        
                $hasWarning = $true
                break
            }
            "^(.*)\((\d+),(\d+)\): error (\w{2,3}\d{4}): (.*)$"
            #Objects\codeunit\Cod50130.name.al(62,30): error AL0118: The name '"Parent Object"' does not exist in the current context        
            {
                $file = $Matches[1]
                if ($file -like "$($basePath)*") {
                    $file = ".\$($file.SubString($basePath.Length))".Replace('\','/')
                }
                if ($gitHubActions) {
                    $newLine = "::error file=$($file),line=$($Matches[2]),col=$($Matches[3])::$($Matches[4]) $($Matches[5])"
                }
                else {
                    $newLine = "##vso[task.logissue type=error;sourcepath=$($file);linenumber=$($Matches[2]);columnnumber=$($Matches[3]);code=$($Matches[4]);]$($Matches[5])"
                }
                $hasError = $true
                break
            }
            "^(.*)error (\w{2,3}\d{4}): (.*)$"
            #error AL0999: Internal error: System.AggregateException: One or more errors occurred. ---> System.InvalidOperationException
            {
                if ($gitHubActions) {
                    $newLine = "::error::$($Matches[2]) $($Matches[3])"
                }
                else {
                    $newLine = "##vso[task.logissue type=error;code=$($Matches[2]);]$($Matches[3])"
                }
                $hasError = $true
                break
            }
            "^(.*)\((\d+),(\d+)\): warning (\w{2,3}\d{4}): (.*)$"
            #Prepared for unified warning format
            #Objects\codeunit\Cod50130.name.al(62,30): warning AL0118: The name '"Parent Object"' does not exist in the current context        
            {
                $file = $Matches[1]
                if ($file -like "$($basePath)*") {
                    $file = ".\$($file.SubString($basePath.Length))".Replace('\','/')
                }
                if ($gitHubActions) {
                    $newLine = "::warning file=$($file),line=$($Matches[2]),col=$($Matches[3])::$($Matches[4]) $($Matches[5])"
                }
                else {
                    $newLine = "##vso[task.logissue type=warning;sourcepath=$($file);linenumber=$($Matches[2]);columnnumber=$($Matches[3]);code=$($Matches[4]);]$($Matches[5])"
                }
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
    if ($gitHubActions) {
        if ($FailOn -eq 'warning' -and $hasWarning) {
            $errLine = "::Error::Failing build as warnings exists"
            $host.SetShouldExit(1)
        }
    }
    else {
        if (($FailOn -eq 'error' -and $hasError) -or ($FailOn -eq 'warning' -and ($hasError -or $hasWarning))) {
            $errLine = "##vso[task.complete result=Failed;]Failed."
        }
        elseif ($failOn -eq 'error' -and $hasWarning) {
            $errLine = "##vso[task.complete result=SucceededWithIssues;]Succeeded With Issues."
        }
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
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Convert-AlcOutputToAzureDevOps -Value Convert-AlcOutputToDevOps
Export-ModuleMember -Function Convert-AlcOutputToDevOps -Alias Convert-AlcOutputToAzureDevOps
