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

    function AddValueToHashTable {
        Param(
            [hashtable] $ht,
            [string] $name,
            $value,
            [switch] $recurse
        )

        if ($ht.Contains($name)) {
            throw "Duplicate key $name"
        }
        if ($recurse -and ($value -is [System.Collections.Specialized.OrderedDictionary] -or $value -is [hashtable] -or $value -is [System.Management.Automation.PSCustomObject])) {
            $ht[$name] = ConvertTo-HashTable $value -recurse
        }
        elseif ($recurse -and $value -is [array]) {
            $ht[$name] = @($value | ForEach-Object { 
                if (($_ -is [System.Collections.Specialized.OrderedDictionary]) -or ($_ -is [hashtable]) -or ($_ -is [System.Management.Automation.PSCustomObject])) {
                    ConvertTo-HashTable $_ -recurse
                }
                else {
                    $_
                }
            })
        }
        else {
            $ht[$name] = $value
        }
    }

    $ht = @{}
    if ($object -is [System.Collections.Specialized.OrderedDictionary] -or $object -is [hashtable]) {
        $object.Keys | ForEach-Object {
            AddValueToHashTable -ht $ht -name $_ -value $object."$_" -recurse:$recurse
        }
    }
    elseif ($object -is [System.Management.Automation.PSCustomObject]) {
        $object.PSObject.Properties | ForEach-Object {
            AddValueToHashTable -ht $ht -name $_.Name -value $_.Value -recurse:$recurse
        }
    }
    $ht
}
Export-ModuleMember -Function ConvertTo-HashTable
