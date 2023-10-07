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
            Write-Host $_.length
            if ($_.length -lt 15000) {
                $arguments += """$($_.Replace('"','\"'))"" "
            }
            else {
                $arguments += """$($_.SubString(0,15000).Replace('"','\"'))`n`nTruncated due to size limits"" "
            }


        }
        else {
            $arguments += "$_ "
        }
    }
    cmdDo -command gh -arguments $arguments -silent:$silent -returnValue:$returnValue -inputStr $inputStr
}

Export-ModuleMember -Function Invoke-gh
