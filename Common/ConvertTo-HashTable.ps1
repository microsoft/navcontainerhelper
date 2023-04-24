<#
 .Synopsis
  Convert PSCustomObject to HashTable
 .Description
  Convert PSCustomObject to HashTable
 .Example
  Get-Content "test.json" | ConvertFrom-Json | ConvertTo-HashTable
#>
function ConvertTo-HashTable() {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [PSCustomObject] $object,
        [switch] $recurse
    )
    $ht = @{}
    if ($object) {
        $object.PSObject.Properties | ForEach-Object { 
            if ($recurse -and ($_.Value -is [PSCustomObject])) {
                $ht[$_.Name] = ConvertTo-HashTable $_.Value
            }
            else {
                $ht[$_.Name] = $_.Value
            }
        }
    }
    $ht
}
Export-ModuleMember -Function ConvertTo-HashTable
