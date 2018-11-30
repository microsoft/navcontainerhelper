function Download-File {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$sourceUrl,
        [Parameter(Mandatory=$true)]
        [string]$destinationFile,
        [switch]$dontOverwrite
    )

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
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
Export-ModuleMember Download-File
