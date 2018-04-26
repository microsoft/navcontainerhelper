function Remove-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    $filename = Join-Path ([Environment]::GetFolderPath("Desktop")) "$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }
    $filename = Join-Path ([Environment]::GetFolderPath("StartMenu")) "NavContainerHelper\$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }
    $filename = Join-Path ([Environment]::GetFolderPath("CommonStartMenu")) "NavContainerHelper\$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }
}
Export-ModuleMember Remove-DesktopShortcut
