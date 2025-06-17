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
    if ("$hostOsVersion" -lt [System.Version]"10.0.17763.0") {
        # Everything before Windows Server 2019 uses ltsc2016
        $ltscVersion = 'ltsc2016'
    }
    elseif ("$hostOsVersion" -lt [System.Version]"10.0.20348.0") {
        # Everything before Windows Server 2022 uses ltsc2019
        $ltscVersion = 'ltsc2019'
    }
    elseif ("$hostOsVersion" -lt [System.Version]"10.0.26100.0") {
        # Default is ltsc2022
        $ltscVersion = 'ltsc2022'
    }
    else {
        # Default is ltsc2025
        $ltscVersion = 'ltsc2025'
    }

    if ($filesOnly) {
        $genericImageNameSetting = $bcContainerHelperConfig.genericImageNameFilesOnly.Replace('{1}', $ltscVersion)
    }
    else {
        $genericImageNameSetting = $bcContainerHelperConfig.genericImageName.Replace('{1}', $ltscVersion)
    }

    return $genericImageNameSetting.Replace('{0}', $ltscVersion).Replace('{1}', $ltscVersion)
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
