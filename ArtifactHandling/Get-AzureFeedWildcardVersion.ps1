function Get-AzureFeedWildcardVersion {
    param (
        [Parameter(Mandatory=$true)]
        [string] $appVersion
    )

    $version = $appVersion.split('.')

    $major = $version[0]
    $minor = $version[1]
    $patch = $version[2]

    if($major -eq '0') { 
        $major = '*';
    }

    if(($minor -eq '0') -and ($patch -eq '0')) { 
        $minor = '*';
    }

    if($patch -eq '0') { 
        $patch = '*';
    } 

    return ($major + '.' + $minor + '.' + $patch)     
}
Export-ModuleMember -Function Get-AzureFeedWildcardVersion
