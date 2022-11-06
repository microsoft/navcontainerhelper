﻿<# 
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

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

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
        $genericImageNameSetting = $bcContainerHelperConfig.genericImageNameFilesOnly
    }
    else {
        $genericImageNameSetting = $bcContainerHelperConfig.genericImageName
    }
    $repo = $genericImageNameSetting.Split(':')[0]
    $tag = $genericImageNameSetting.Split(':')[1].Replace('{0}','*')
    if ($tag.indexOf('*') -lt 0) {
        $genericImageNameSetting
    }
    else {
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
                "10.0.14393.4169"
                "10.0.14393.4225"
                "10.0.14393.4283"
                "10.0.14393.4350"
                "10.0.14393.4402"
                "10.0.14393.4467"
                "10.0.14393.4470"
                "10.0.14393.4530"
                "10.0.14393.4583"
                "10.0.14393.4651"
                "10.0.14393.4704"
                "10.0.14393.4770"
                "10.0.14393.4825"
                "10.0.14393.4886"
                "10.0.14393.4946"
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
                "10.0.17763.1697"
                "10.0.17763.1757"
                "10.0.17763.1817"
                "10.0.17763.1879"
                "10.0.17763.1935"
                "10.0.17763.1999"
                "10.0.17763.2029"
                "10.0.17763.2061"
                "10.0.17763.2114"
                "10.0.17763.2183"
                "10.0.17763.2237"
                "10.0.17763.2300"
                "10.0.17763.2366"
                "10.0.17763.2452"
                "10.0.17763.2565"
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
                "10.0.18363.1377"
                "10.0.18363.1440"
                "10.0.18363.1500"
                "10.0.18363.1556"
                "10.0.18363.476"
                "10.0.18363.535"
                "10.0.18363.592"
                "10.0.18363.658"
                "10.0.18363.778"
                "10.0.18363.900"
                "10.0.18363.959"
                "10.0.19041.1052"
                "10.0.19041.1083"
                "10.0.19041.1110"
                "10.0.19041.1165"
                "10.0.19041.1237"
                "10.0.19041.1288"
                "10.0.19041.1348"
                "10.0.19041.1415"
                "10.0.19041.329"
                "10.0.19041.388"
                "10.0.19041.450"
                "10.0.19041.508"
                "10.0.19041.572"
                "10.0.19041.630"
                "10.0.19041.685"
                "10.0.19041.746"
                "10.0.19041.804"
                "10.0.19041.867"
                "10.0.19041.928"
                "10.0.19041.985"
                "10.0.19042.1052"
                "10.0.19042.1083"
                "10.0.19042.1110"
                "10.0.19042.1165"
                "10.0.19042.1237"
                "10.0.19042.1288"
                "10.0.19042.1348"
                "10.0.19042.1415"
                "10.0.19042.1466"
                "10.0.19042.1526"
                "10.0.19042.572"
                "10.0.19042.630"
                "10.0.19042.685"
                "10.0.19042.746"
                "10.0.19042.804"
                "10.0.19042.867"
                "10.0.19042.928"
                "10.0.19042.985"
                "10.0.20348.169"
                "10.0.20348.288"
                "10.0.20348.350"
                "10.0.20348.405"
                "10.0.20348.469"
                "10.0.20348.524"
            ) | ForEach-Object { [System.Version]$_ } | Sort-Object
        }
        
        $genericImageName = ""
        $myversions = $versions | Where-Object { $_.Major -eq $hostOsVersion.Major -and $_.Minor -eq $hostOsVersion.Minor -and $_.Build -eq $hostOsVersion.Build } | Sort-Object
        if (-not $myversions) {
            if (-not $onlyMatchingBuilds) {
                if ($hostOsVersion.Build -eq 19043 -or $hostOsVersion.Build -eq 19044 -or $hostOsVersion.Build -eq 19045) {
                    # 21H1 doesn't work well with 20H2 servercore images - grab 2004 if no corresponding image exists
                    Write-Host -ForegroundColor Yellow "INFO: Windows 10 21H1/21H2 images are not yet available, using 2004 as these are found to work better than 20H2 on 21H1/21H2"
                    $myversions = $versions | Where-Object { $_.Build -eq 19041 } | Sort-Object
                }
                else {
                    $myversions = $versions | Sort-Object
                }
            }
        }
        if ($myversions) {
            $version = $myversions | Where-Object { $_ -le $hostOsVersion } | Select-Object -Last 1
            if (-not $version) {
                $version = $myversions | Select-Object -First 1
            }
            $genericImageName = [string]::format($genericImageNameSetting, $version.ToString())
        }
        $genericImageName
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Get-BestGenericImageName
