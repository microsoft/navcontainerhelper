<# 
 .Synopsis
  Get Best Generic NAV/BC Container Image Name
 .Description
  If the best matching generic container name based on the Host Operating system. Returns blank if no generic matches the host OS.
 .Example
  $genericImageName = Get-BestGenericImageName
#>
function Get-BestGenericImageName {
    Param (
        [switch] $onlyMatchingBuilds
    )

    $os = (Get-CimInstance Win32_OperatingSystem)
    if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
        throw "Unknown Host Operating System"
    }

    $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
    $hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")

    $imagetags = Get-NavContainerImageTags -imageName "mcr.microsoft.com/dynamicsnav"
    $versions = @()
    if ($imagetags) {
        $versions = $imagetags.tags | Where-Object { $_.startswith('10.0.') -and $_.endswith('-generic') } | % { [System.Version]($_.SubString(0,$_.IndexOf('-'))) }
    }
    if (-not $versions) {

        # ImageTags not yet updated - use hardcoded list

        $versions = @(
        "10.0.14393.2906-generic"
        "10.0.17763.437-generic"
        "10.0.18362.116-generic"
        "10.0.14393.2972-generic"
        "10.0.17763.504-generic"
        "10.0.18362.175-generic"
        "10.0.14393.3025-generic"
        "10.0.17763.557-generic"
        "10.0.18362.239-generic"
        "10.0.14393.3085-generic"
        "10.0.17763.615-generic"
        "10.0.17134.950-generic"
        "10.0.18362.295-generic"
        "10.0.14393.3144-generic"
        "10.0.17763.678-generic"
        "10.0.17134.1006-generic"
        "10.0.18362.356-generic"
        "10.0.14393.3204-generic"
        "10.0.17763.737-generic"
        "10.0.17134.1130-generic"
        "10.0.18362.476-generic"
        "10.0.14393.3326-generic"
        "10.0.17763.864-generic"
        "10.0.18363.476-generic"
        "10.0.18362.535-generic"
        "10.0.18363.535-generic"
        "10.0.14393.3384-generic"
        "10.0.17763.914-generic"
        "10.0.18362.592-generic"
        "10.0.18363.592-generic"
        "10.0.14393.3443-generic"
        "10.0.17763.973-generic"
        "10.0.18362.658-generic"
        "10.0.18363.658-generic"
        "10.0.14393.3506-generic"
        "10.0.17763.1040-generic"
        ) | % { [System.Version]($_.SubString(0,$_.IndexOf('-'))) }
    }
    
    $genericImageName = ""
    $myversions = $versions | Where-Object { $_.Major -eq $hostOsVersion.Major -and $_.Minor -eq $hostOsVersion.Minor -and $_.Build -eq $hostOsVersion.Build } | Sort-Object
    if (-not $myversions) {
        if (-not $onlyMatchingBuilds) {
            $myversions = $versions | Sort-Object
        }
    }
    if ($myversions) {
        $version = $myversions | Where-Object { $_ -ge $hostOsVersion } | Select-Object -First 1
        if (-not $version) {
            $version = $myversions | Select-Object -Last 1
        }
        $genericImageName = "mcr.microsoft.com/dynamicsnav:$($version.ToString())-generic"
    }
    $genericImageName
}
Export-ModuleMember -Function Get-BestGenericImageName
