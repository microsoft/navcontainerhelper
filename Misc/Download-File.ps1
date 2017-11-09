function Download-File {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$sourceUrl,
        [Parameter(Mandatory=$true)]
        [string]$destinationFile
    )

    Write-Host "Downloading $destinationFile"
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
Export-ModuleMember Download-File
