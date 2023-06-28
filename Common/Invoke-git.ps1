<# 
 .Synopsis
  Invoke git command with parameters
 .Description
  Requires Git installed  
#>
function invoke-git {
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
        cmdDo -command git -arguments $arguments -silent:$silent -returnValue:$returnValue -inputStr $inputStr
    }
    catch [System.Management.Automation.MethodInvocationException] {
        throw "It looks like Git is not installed. Please install Git from https://git-scm.com/download"
    }
}
Export-ModuleMember -Function Invoke-git
