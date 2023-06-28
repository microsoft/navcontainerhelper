<# 
 .Synopsis
  Invoke gh command with parameters
 .Description
  Requires Github CLI installed  
#>
function invoke-gh {
    Param(
        [parameter(mandatory = $false, ValueFromPipeline = $true)]
        [string] $inputStr = "",
        [switch] $silent,
        [switch] $returnValue,
        [parameter(mandatory = $true, position = 0)][string] $command,
        [parameter(mandatory = $false, position = 1, ValueFromRemainingArguments = $true)] $remaining
    )

    $arguments = "$command "
    $remaining | ForEach-Object {
        if ("$_".IndexOf(" ") -ge 0 -or "$_".IndexOf('"') -ge 0) {
            $arguments += """$($_.Replace('"','\"'))"" "
        }
        else {
            $arguments += "$_ "
        }
    }
    try {
        cmdDo -command gh -arguments $arguments -silent:$silent -returnValue:$returnValue -inputStr $inputStr
    }
    catch [System.Management.Automation.MethodInvocationException] {
        throw "It looks like GitHub CLI is not installed. Please install GitHub CLI from https://cli.github.com/"
    }
}

Export-ModuleMember -Function Invoke-gh
