function New-DesktopShortcut {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name, 
        [Parameter(Mandatory=$true)]
        [string]$TargetPath, 
        [string]$WorkingDirectory = "", 
        [string]$IconLocation = "", 
        [string]$Arguments = "",
        [string]$FolderName = "Desktop",
        [switch]$RunAsAdministrator = $true
    )
    $filename = Join-Path ([Environment]::GetFolderPath($FolderName)) "$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }

    $Shell =  New-object -comobject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($filename)
    $Shortcut.TargetPath = $TargetPath
    if (!$WorkingDirectory) {
        $WorkingDirectory = Split-Path $TargetPath
    }
    $Shortcut.WorkingDirectory = $WorkingDirectory
    if ($Arguments) {
        $Shortcut.Arguments = $Arguments
    }
    if ($IconLocation) {
        $Shortcut.IconLocation = $IconLocation
    }
    $Shortcut.save()
    if ($RunAsAdministrator) {
        $bytes = [System.IO.File]::ReadAllBytes($filename)
        $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
        [System.IO.File]::WriteAllBytes($filename, $bytes)
    }
}
Export-ModuleMember New-DesktopShortcut
