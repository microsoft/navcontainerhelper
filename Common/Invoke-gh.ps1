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

    Process {
        $arguments = "$command "
        foreach($parameter in $remaining) {
            if ("$parameter".IndexOf(" ") -ge 0 -or "$parameter".IndexOf('"') -ge 0) {
                if ($parameter.length -gt 15000) {
                    $parameter = "$($parameter.Substring(0,15000))...`n`n**Truncated due to size limits!**"
                }
                $arguments += """$($parameter.Replace('"','\"'))"" "
            }
            else {
                $arguments += "$parameter "
            }
        }
        cmdDo -command gh -arguments $arguments -silent:$silent -returnValue:$returnValue -inputStr $inputStr -messageIfCmdNotFound "Github CLI not found. Please install it from https://cli.github.com/"
    }
}

Export-ModuleMember -Function Invoke-gh
