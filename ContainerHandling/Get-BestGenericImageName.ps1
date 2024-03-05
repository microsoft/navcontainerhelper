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
        $failureDelay = 2
        while ($true) {
            $imagetags = Get-BcContainerImageTags -imageName $repo
            if ($imagetags) {
                $ver = [Version]"0.0.0.0"
                # $tag can be *-filesonly, *-filesonly-dev, *-dev or other patterns
                # * is the Windows version OS version
                $versions = $imagetags.tags |
                                Where-Object { $_ -like $tag -and [System.Version]::TryParse($_.SubString($tag.indexOf('*'), $_.length-$tag.length+1), [ref]$ver) } |
                                ForEach-Object { [System.Version]($_.SubString($tag.indexOf('*'), $_.length-$tag.length+1)) }
                break
            }
            else {
                if ($failureDelay -gt 32) {
                    throw "Unable to download image tags for $repo"
                }
                Write-Host -ForegroundColor Yellow "Unable to download image tags for $repo, retrying in $failureDelay seconds"
                Start-Sleep -Seconds $failureDelay
                $failureDelay = $failureDelay * 2
            }
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
