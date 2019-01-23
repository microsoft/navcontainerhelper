<# 
 .Synopsis
  Checks Permissions for NavContainerHelper to run
 .Description
  When running NavContainerHelper as administrator, you have access to everything.
  When running NavContainerHelper as a user, that user needs:
  - Full control to C:\ProgramData\NavContainerHelper (in order to create and remove containers)
  - Modify permissions to C:\Windows\System32\drivers\etc\hosts (if you use -updatehosts)
  - Full control to docker engine pipe (in order to run docker commands)
  This script checks these permissions and allows you to fix the permissions by specifying -fix
 .Parameter fix
  Specify fix in order for this script to attempt to fix permissions
 .Parameter ignoreHosts
  Specify -ignoreHosts to ignore checking the permissions for the hosts file
 .Example
  Check-Permissions -fix
#>
function Check-Permissions {
    Param(
        [switch] $Fix,
        [switch] $IgnoreHosts
    )

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $user = (whoami)

    if (!$isAdministrator -or $Fix) {
        Write-Host "Running as $user"

        # Check access to C:\ProgramData\NavContainerHelper
        Write-Host "Checking permissions to $hostHelperFolder"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,'FullControl', 3, 'InheritOnly', 'Allow')
        $access = [System.IO.Directory]::GetAccessControl($hostHelperFolder).Access | 
                    Where-Object { $_.IdentityReference -eq $rule.IdentityReference -and $_.FileSystemRights -eq $rule.FileSystemRights -and $_.AccessControlType -eq $rule.AccessControlType -and $_.InheritanceFlags -eq $rule.InheritanceFlags -and $_.PropagationFlags -eq $rule.PropagationFlags }
        
        if ($access) {
            Write-Host -ForegroundColor Green "$user has the right permissions to $hostHelperFolder"
        } else {
            Write-Host -ForegroundColor Red "$user does NOT have Full Control to $hostHelperFolder and all subfolders"
            if (!$Fix) {
                Write-Host -ForegroundColor Red "You need to run as administrator or you can run Check-Permissions -Fix to fix permissions"
            } else {
                Write-Host -ForegroundColor Yellow "Trying to add permissions"
                $scriptblock = {
                    Param($user, $hostHelperFolder)
                    try {
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,'FullControl', 3, 'InheritOnly', 'Allow')
                        $acl = [System.IO.Directory]::GetAccessControl($hostHelperFolder)
                        $acl.AddAccessRule($rule)
                        [System.IO.Directory]::SetAccessControl($hostHelperFolder,$acl) 
                        EXIT 0
                    } catch {
                        EXIT 1
                    }
                }
                $exitCode = (Start-Process powershell -ArgumentList "-command & {$scriptblock} -user '$user' -hostHelperFolder '$hostHelperFolder'" -Verb RunAs -wait -WindowStyle Hidden -PassThru).ExitCode
                if ($exitcode -eq 0) {
                    Write-Host -ForegroundColor Green "Permissions successfully added"
                } else {
                    Write-Host -ForegroundColor Red "Error adding permissions"
                }
            }
        }
    
        if (!$IgnoreHosts) {
            # check access to c:\windows\system32\drivers\etc\hosts
            $hostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
            Write-Host "Checking permissions to $hostsFile"
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,'Modify', 'Allow')
            $access = [System.IO.Directory]::GetAccessControl($hostsFile).Access | 
                        Where-Object { $_.IdentityReference -eq $rule.IdentityReference -and $_.FileSystemRights -eq $rule.FileSystemRights -and $_.AccessControlType -eq $rule.AccessControlType }
    
            if ($access) {
                Write-Host -ForegroundColor Green "$user has the right permissions to $hostsFile"
            } else {
                Write-Host -ForegroundColor Red "$user does NOT have modify permissions to $hostsFile"
                if (!$Fix) {
                    Write-Host -ForegroundColor Red "You need to run as administrator or you can run Check-Permissions -Fix to fix permissions"
                } else {
                    Write-Host -ForegroundColor Yellow "Trying to add permissions"
                    $scriptblock = {
                        Param($user, $hostsFile)
                        try {
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,'Modify', 'Allow')
                            $acl = [System.IO.Directory]::GetAccessControl($hostsFile)
                            $acl.AddAccessRule($rule)
                            [System.IO.Directory]::SetAccessControl($hostsFile,$acl) 
                            EXIT 0
                        } catch {
                            EXIT 1
                        }
                    }
                    $exitcode = (Start-Process powershell -ArgumentList "-command & {$scriptblock} -user '$user' -hostsFile '$hostsFile'" -Verb RunAs -wait -PassThru -WindowStyle Hidden).ExitCode
                    if ($exitcode -eq 0) {
                        Write-Host -ForegroundColor Green "Permissions successfully added"
                    } else {
                        Write-Host -ForegroundColor Red "Error adding permissions"
                    }
                }
            }
        }

        # Check Access to Docker Deamon Socket
        # Thanks to Tobias Fenster, Axians Infoma for this blog post:
        #     https://www.axians-infoma.com/techblog/allow-access-to-the-docker-engine-without-admin-rights-on-windows/
        # Pointing me in the right directions wrt. running docker commands without admin rights
        Write-Host "Checking permissions to docker commands"
        $npipe = ""
        $dockerOk = $true
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $ps = docker ps 2> $tempFile
            if ($LASTEXITCODE -ne 0) {
                $dockerOk = $false
                $err = [System.IO.File]::ReadAllText($tempFile)
                Remove-Item -Path $tempFile -ErrorAction Ignore
                $npipeStart = $err.IndexOf('\\.\pipe')
                $npipeEnd = $err.IndexOf(': Access is denied')
                $npipe = $err.SubString($npipeStart, $npipeEnd-$npipeStart)
            }
        } catch {
        }

        if ($dockerOk) {
            Write-Host -ForegroundColor Green "$user has the right permissions to run docker commands"
        } else {
            Write-Host -ForegroundColor Red "$user does NOT have permissions to run docker commands"
            if (!$Fix) {
                Write-Host -ForegroundColor Red "You need to run as administrator or you can run Check-Permissions -Fix to fix permissions"
            } else {
                if ($npipe -eq "") {
                    Write-Host -ForegroundColor Red "Unable to determine docker deamon socket. Are you sure Docker is running and reachable?"
                } else {
                    Write-Host -ForegroundColor Yellow "Trying to add permissions"
                    $scriptblock = {
                        Param($user, $npipe)
                        try {
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,'FullControl', 'Allow')
                            $acl = [System.IO.Directory]::GetAccessControl($npipe)
                            $acl.AddAccessRule($rule)
                            [System.IO.Directory]::SetAccessControl($npipe,$acl) 
                            exit 0
                        } catch {
                            exit 1
                        }
                    }
            
                    $exitcode = (Start-Process powershell -ArgumentList "-command & {$scriptblock} -user '$user' -npipe '$npipe'" -Verb RunAs -wait -PassThru).ExitCode
                    if ($exitcode -eq 0) {
                        Write-Host -ForegroundColor Green "Permissions successfully added"
                    } else {
                        Write-Host -ForegroundColor Red "Error adding permissions"
                    }
                }
            }
        }
    }
}
Export-ModuleMember -Function Check-Permissions

