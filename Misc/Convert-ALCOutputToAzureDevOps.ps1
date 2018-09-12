function Convert-ALCOutputToAzureDevOps {
    Param()
    Process {
        switch -regex ($_) {
            "^warning (\w{2}\d{4}):(.*('.*').*|.*)$" {
                if (Test-Path $Matches[3]) {
                    Write-Host "##vso[task.logissue type=warning;sourcepath=$($Matches[3]);code=$($Matches[1]);]$($Matches[2])"
                } else {
                    Write-Host "##vso[task.logissue type=warning;code=$($Matches[1]);]$($Matches[2])"
                }

            }
            "^(.*)\((\d+),(\d+)\): error (\w{2}\d{4}): (.*)$"
            #Objects\codeunit\Cod50130.name.al(62,30): error AL0118: The name '"Parent Object"' does not exist in the current context        
            {
                Write-Host "##vso[task.logissue type=error;sourcepath=$($Matches[1]);linenumber=$($Matches[2]);columnnumber=$($Matches[3]);code=$($Matches[4]);]$($Matches[5])"
            }
            "^(.*)\((\d+),(\d+)\): warning (\w{2}\d{4}): (.*)$"
            #Prepared for unified warning format
            #Objects\codeunit\Cod50130.name.al(62,30): warning AL0118: The name '"Parent Object"' does not exist in the current context        
            {
                Write-Host "##vso[task.logissue type=warning;sourcepath=$($Matches[1]);linenumber=$($Matches[2]);columnnumber=$($Matches[3]);code=$($Matches[4]);]$($Matches[5])"
            }
            default {
                Write-Host $_
            }
        }
    }
}
Export-ModuleMember Convert-ALCOutputToAzureDevOps