﻿<# 
 .Synopsis
  Remove a shortcut
 .Description
  Remove a shortcut
 .Parameter Name
  Name of shortcut to remove from all locations
#>
function Remove-DesktopShortcut {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Name
    )
    "Desktop","CommonDesktop" | % {
        $environmentPath = [Environment]::GetFolderPath($_)
        If ($environmentPath -ne "") {
            $filename = Join-Path $environmentPath "$Name.lnk"
            if (Test-Path -Path $filename -PathType Leaf) {
                Remove-Item $filename -force
            }
            else {
                $folderName = $Name.Split(' ')[0]
                $shortcutName = $name.Substring($folderName.Length).TrimStart(' ')
                $folderName = Join-Path $environmentPath $folderName
                $filename = Join-Path $foldername "$shortcutName.lnk"
                if (Test-Path -Path $filename -PathType leaf) {
                    Remove-Item $filename -Force
                    try {
                        Remove-Item $folderName -Recurse -force
                    } catch {}
                }                
            }
        }
    }
    "StartMenu","CommonStartMenu" | % {
        $environmentPath = [Environment]::GetFolderPath($_)
        if ($environmentPath -ne "") {
            $filename = Join-Path $environmentPath "BcContainerHelper\$Name.lnk"
            if (Test-Path -Path $filename) {
                Remove-Item $filename -force
            }
        }
    }
}
Export-ModuleMember -Function Remove-DesktopShortcut
