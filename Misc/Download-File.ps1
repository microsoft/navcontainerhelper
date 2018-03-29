function Download-File {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$sourceUrl,
        [Parameter(Mandatory=$true)]
        [string]$destinationFile
    )

    Write-Host "Downloading $destinationFile"
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
Export-ModuleMember Download-File
