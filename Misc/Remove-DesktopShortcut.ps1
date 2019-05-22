function Remove-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $environmentPath = [Environment]::GetFolderPath("Desktop")
    If ($environmentPath -ne "") {
        $filename = Join-Path $environmentPath "$Name.lnk"
        if (Test-Path -Path $filename) {
            Remove-Item $filename -force
        }
    }
    $environmentPath = [Environment]::GetFolderPath("StartMenu")
    if ($environmentPath -ne "") {
        $filename = Join-Path $environmentPath "NavContainerHelper\$Name.lnk"
        if (Test-Path -Path $filename) {
            Remove-Item $filename -force
        }
    }
    $environmentPath = [Environment]::GetFolderPath("CommonStartMenu")
    if ($environmentPath -ne "") {
        $filename = Join-Path $environmentPath "NavContainerHelper\$Name.lnk"
        if (Test-Path -Path $filename) {
            Remove-Item $filename -force
        }
    }
}
Export-ModuleMember -Function * -Alias *
