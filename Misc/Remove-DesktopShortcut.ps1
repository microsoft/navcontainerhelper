function Remove-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$FolderName = "Desktop"
    )
    $filename = Join-Path ([Environment]::GetFolderPath($FolderName)) "$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }
}
Export-ModuleMember Remove-DesktopShortcut
