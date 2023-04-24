<#
 .Synopsis
  Convert SecureString to Plain Text
 .Description
  Convert SecureString to Plain Text
 .Parameter secureString
  Secure String to convert to plain text
 .Example
  Get-PlainText -secureString $credential.Password
#>
function Get-PlainText() {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline, Mandatory = $true)]
        [System.Security.SecureString] $SecureString
    )
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString);
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr);
    }
    finally {
        [Runtime.InteropServices.Marshal]::FreeBSTR($bstr);
    }
}
Export-ModuleMember -Function Get-PlainText
