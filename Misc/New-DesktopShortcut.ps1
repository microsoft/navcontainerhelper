<# 
 .Synopsis
  Create a Desktop shortcut
 .Description
  Create a Desktop shortcut
 .Parameter Name
  Name of shortcut
 .Parameter TargetPath
  TargetPath of shortcut
 .Parameter WorkingDirectory
  Working Directory of shortcut
 .Parameter IconLocation
  Icon location for shortcut
 .Parameter Arguments
  Arguments for the program executed by shortcut
 .Parameter shortcuts
  Specify where you want to shortcut created: ('None','Desktop','StartMenu','Startup','CommonDesktop','CommonStartMenu','CommonStartup')
 .Parameter RunAsAdministrator
  Include this switch if you want the shortcut to be set to Run As Administrator
#>
function New-DesktopShortcut {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Name, 
        [Parameter(Mandatory=$true)]
        [string] $TargetPath, 
        [string] $WorkingDirectory = "", 
        [string] $IconLocation = "", 
        [string] $Arguments = "",
        [ValidateSet('None','Desktop','StartMenu','Startup','CommonDesktop','CommonStartMenu','CommonStartup')]
        [string] $shortcuts = "Desktop",
        [switch] $RunAsAdministrator = $isAdministrator
    )
    if ($shortcuts -ne "None") {
        
        if ($shortcuts -eq "Desktop" -or 
            $shortcuts -eq "CommonDesktop" -or 
            $shortcuts -eq "Startup" -or 
            $shortcuts -eq "CommonStartup") {
            $folder = [Environment]::GetFolderPath($shortcuts)
        } else {
            $folder = Join-Path ([Environment]::GetFolderPath($shortcuts)) "NavContainerHelper"
            if (!(Test-Path $folder -PathType Container)) {
                New-Item $folder -ItemType Directory | Out-Null
            }
        }

        if ($folder) {
            $filename = Join-Path $folder "$Name.lnk"
            if (Test-Path -Path $filename) {
                Remove-Item $filename -force
            }
        
            $tempfilename = Join-Path $containerHelperFolder "$([Guid]::NewGuid().ToString()).lnk"
            $Shell =  New-object -comobject WScript.Shell
            $Shortcut = $Shell.CreateShortcut($tempfilename)
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
            Move-Item -Path $tempfilename -Destination $filename

            if ($RunAsAdministrator) {
                $bytes = [System.IO.File]::ReadAllBytes($filename)
                $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
                [System.IO.File]::WriteAllBytes($filename, $bytes)
            }
        }
    }
}
Export-ModuleMember -Function New-DesktopShortcut
