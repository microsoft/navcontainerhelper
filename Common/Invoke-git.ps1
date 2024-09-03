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

    Process {
        $arguments = "$command "
        foreach($parameter in $remaining) {
            if ("$parameter".IndexOf(" ") -ge 0 -or "$parameter".IndexOf('"') -ge 0) {
                $arguments += """$($parameter.Replace('"','\"'))"" "
            }
            else {
                $arguments += "$parameter "
            }
        }
        cmdDo -command git -arguments $arguments -silent:$silent -returnValue:$returnValue -inputStr $inputStr -messageIfCmdNotFound "Git not found. Please install it from https://git-scm.com/downloads"
    }
}
Export-ModuleMember -Function Invoke-git
