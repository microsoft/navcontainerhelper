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
        [switch] $onlyMatchingBuilds,
        [Version] $hostOsVersion = $null,
        [switch] $filesOnly
    )

    if ($hostOsVersion -eq $null) {
        $os = (Get-CimInstance Win32_OperatingSystem)
        if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
            throw "Unknown Host Operating System"
        }
    
        $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
        $hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")
    }
    else {
        $revision = $hostOsVersion.Revision
        if ($revision -eq -1) { $revision = [int32]::MaxValue }
        $build = $hostOsVersion.Build
        if ($build -eq -1) { $build = [int32]::MaxValue }
        $hostOsVersion = [System.Version]::new($hostOsVersion.Major, $hostOsVersion.Minor, $build, $revision)
    }

    if ($filesOnly) {
        $genericImageNameSetting = (Get-ContainerHelperConfig).genericImageNameFilesOnly
    }
    else {
        $genericImageNameSetting = (Get-ContainerHelperConfig).genericImageName
    }
    $repo = $genericImageNameSetting.Split(':')[0]
    $tag = $genericImageNameSetting.Split(':')[1].Replace('{0}','*')

    $imagetags = Get-BcContainerImageTags -imageName $repo
    $versions = @()
    if ($imagetags) {
        $ver = [Version]"0.0.0.0"
        $versions = $imagetags.tags | Where-Object { $_ -like $tag -and [System.Version]::TryParse($_.SubString($tag.indexOf('*'), $_.length-$tag.length+1), [ref]$ver) } | % { [System.Version]($_.SubString($tag.indexOf('*'), $_.length-$tag.length+1)) }
    }
    if (-not $versions) {

        # ImageTags not yet updated - use hardcoded list
        $versions = @(
        "10.0.14393.2906"
        "10.0.14393.2972"
        "10.0.14393.3025"
        "10.0.14393.3085"
        "10.0.14393.3144"
        "10.0.14393.3204"
        "10.0.14393.3326"
        "10.0.14393.3384"
        "10.0.14393.3443"
        "10.0.14393.3630"
        "10.0.14393.3750"
        "10.0.14393.3808"
        "10.0.14393.3866"
        "10.0.14393.3930"
        "10.0.14393.3986"
        "10.0.14393.4046"
        "10.0.14393.4104"
        "10.0.17134.1006"
        "10.0.17134.1130"
        "10.0.17134.706"
        "10.0.17134.766"
        "10.0.17134.829"
        "10.0.17134.885"
        "10.0.17134.950"
        "10.0.17763.1158"
        "10.0.17763.1282"
        "10.0.17763.1339"
        "10.0.17763.1397"
        "10.0.17763.1457"
        "10.0.17763.1518"
        "10.0.17763.1577"
        "10.0.17763.1637"
        "10.0.17763.437"
        "10.0.17763.504"
        "10.0.17763.557"
        "10.0.17763.615"
        "10.0.17763.678"
        "10.0.17763.737"
        "10.0.17763.864"
        "10.0.17763.914"
        "10.0.17763.973"
        "10.0.18362.1016"
        "10.0.18362.1082"
        "10.0.18362.1139"
        "10.0.18362.116"
        "10.0.18362.1198"
        "10.0.18362.175"
        "10.0.18362.239"
        "10.0.18362.295"
        "10.0.18362.356"
        "10.0.18362.476"
        "10.0.18362.535"
        "10.0.18362.592"
        "10.0.18362.658"
        "10.0.18362.778"
        "10.0.18362.900"
        "10.0.18362.959"
        "10.0.18363.1016"
        "10.0.18363.1082"
        "10.0.18363.1139"
        "10.0.18363.1198"
        "10.0.18363.1256"
        "10.0.18363.476"
        "10.0.18363.535"
        "10.0.18363.592"
        "10.0.18363.658"
        "10.0.18363.778"
        "10.0.18363.900"
        "10.0.18363.959"
        "10.0.19041.329"
        "10.0.19041.388"
        "10.0.19041.450"
        "10.0.19041.508"
        "10.0.19041.572"
        "10.0.19041.630"
        "10.0.19041.685"
        "10.0.19042.572"
        "10.0.19042.630"
        "10.0.19042.685"
        ) | ForEach-Object { [System.Version]$_ } | Sort-Object
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
        $genericImageName = [string]::format($genericImageNameSetting, $version.ToString())
    }
    $genericImageName
}
Export-ModuleMember -Function Get-BestGenericImageName
