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
        $object,
        [switch] $recurse
    )
    $ht = @{}
    if ($object -is [System.Collections.Specialized.OrderedDictionary] -or $object -is [hashtable]) {
        $object.Keys | ForEach-Object {
            if ($recurse -and ($object."$_" -is [System.Collections.Specialized.OrderedDictionary] -or $object."$_" -is [hashtable] -or $object."$_" -is [PSCustomObject])) {
                $ht[$_] = ConvertTo-HashTable $object."$_" -recurse
            }
            else {
                $ht[$_] = $object."$_"
            }
        }
    }
    elseif ($object -is [PSCustomObject]) {
        $object.PSObject.Properties | ForEach-Object {
            Write-Host "Property $_"
            if ($recurse -and ($object."$_" -is [System.Collections.Specialized.OrderedDictionary] -or $object."$_" -is [hashtable] -or $object."$_" -is [PSCustomObject])) {
                $ht[$_.Name] = ConvertTo-HashTable $_.Value -recurse
            }
            else {
                $ht[$_.Name] = $_.Value
            }
        }
    }
    $ht
}
Export-ModuleMember -Function ConvertTo-HashTable
