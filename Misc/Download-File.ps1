<#
 .Synopsis
  Download File
 .Description
  Download a file to local computer
 .Parameter sourceUrl
  Url from which the file will get downloaded
 .Parameter destinationFile
  Destinatin for the downloaded file
 .Parameter dontOverwrite
  Specify dontOverwrite if you want top skip downloading if the file already exists
 .Parameter timeout
  Timeout in seconds for the download
 .Example
  Download-File -sourceUrl "https://myurl/file.zip" -destinationFile "c:\temp\file.zip" -dontOverwrite
#>
function Download-File {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $sourceUrl,
        [Parameter(Mandatory=$true)]
        [string] $destinationFile,
        [switch] $dontOverwrite,
        [int]    $timeout = 100
    )

    $replaceUrls = @{
        "https://go.microsoft.com/fwlink/?LinkID=844461" = "https://bcartifacts.azureedge.net/prerequisites/DotNetCore.1.0.4_1.1.1-WindowsHosting.exe"
        "https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi" = "https://bcartifacts.azureedge.net/prerequisites/rewrite_2.0_rtw_x64.msi"
        "https://download.microsoft.com/download/5/5/3/553C731E-9333-40FB-ADE3-E02DC9643B31/OpenXMLSDKV25.msi" = "https://bcartifacts.azureedge.net/prerequisites/OpenXMLSDKv25.msi"
        "https://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi" = "https://bcartifacts.azureedge.net/prerequisites/ReportViewer.msi"
        "https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x86/SQLSysClrTypes.msi" = "https://bcartifacts.azureedge.net/prerequisites/SQLSysClrTypes.msi"
        "https://download.microsoft.com/download/3/A/6/3A632674-A016-4E31-A675-94BE390EA739/ENU/x64/sqlncli.msi" = "https://bcartifacts.azureedge.net/prerequisites/sqlncli.msi"
        "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe" = "https://bcartifacts.azureedge.net/prerequisites/vcredist_x86.exe"
    }

    if ($replaceUrls.ContainsKey($sourceUrl)) {
        $sourceUrl = $replaceUrls[$sourceUrl]
    }

    if (Test-Path $destinationFile -PathType Leaf) {
        if ($dontOverwrite) { 
            return
        }
        Remove-Item -Path $destinationFile -Force
    }
    $path = [System.IO.Path]::GetDirectoryName($destinationFile)
    if (!(Test-Path $path -PathType Container)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Downloading $destinationFile"
    try {
        (New-Object TimeoutWebClient -ArgumentList (1000*$timeout)).DownloadFile($sourceUrl, $destinationFile)
    }
    catch {
        if ($sourceUrl -notlike "https://bcartifacts.azureedge.net/*" -and
            $sourceUrl -notlike "https://bcinsider.azureedge.net/*" -and
            $sourceUrl -notlike "https://bcprivate.azureedge.net/*" -and
            $sourceUrl -notlike "https://bcpublicpreview.azureedge.net/*") {
            throw
        }
        $idx = $sourceUrl.IndexOf('.azureedge.net/',[System.StringComparison]::InvariantCultureIgnoreCase)
        $newSourceUrl = $sourceUrl.Substring(0,$idx) + '.blob.core.windows.net' + $sourceUrl.Substring($idx + 14)
        Write-Host "Could not download from $($sourceUrl.SubString(0,$idx + 14))/..., retrying from $($newSourceUrl.SubString(0,$idx + 22))/..."
        (New-Object TimeoutWebClient -ArgumentList (1000*$timeout)).DownloadFile($newSourceUrl, $destinationFile)
    }
}
Export-ModuleMember -Function Download-File
