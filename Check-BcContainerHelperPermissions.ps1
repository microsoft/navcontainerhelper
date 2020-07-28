<# 
 .Synopsis
  Checks Permissions for BcContainerHelper to run
 .Description
  When running BcContainerHelper as administrator, you have access to everything.
  When running BcContainerHelper as a user, that user needs:
  - Full control to C:\ProgramData\BcContainerHelper (in order to create and remove containers)
  - Modify permissions to C:\Windows\System32\drivers\etc\hosts (if you use -updatehosts)
  - Full control to docker engine pipe (in order to run docker commands)
  This script checks these permissions and allows you to fix the permissions by specifying -fix
 .Parameter fix
  Specify fix in order for this script to attempt to fix permissions
 .Parameter silent
  Specify -silent to stay silent on successfull permission checks
 .Parameter ignoreHosts
  Specify -ignoreHosts to ignore checking the permissions for the hosts file
 .Example
  Check-BcContainerHelperPermissions -fix
 .Example
  Check-BcContainerHelperPermissions -fix -ignoreHosts
 .Example
  Check-BcContainerHelperPermissions -silent
#>
function Check-BcContainerHelperPermissions {
    Param (
        [switch] $Fix,
        [switch] $Silent,
        [switch] $IgnoreHosts
    )

    if (!$isAdministrator -or $Fix) {
        if (!$silent) {
            if ($isAdministrator) {
                Write-Host "Running as administrator"
            } else {
                Write-Host "Running as $myUsername"
            }
        }

        # Check access to C:\ProgramData\BcContainerHelper
        if (!$silent) {
            Write-Host "Checking permissions to $hostHelperFolder"
        }
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 3, 'InheritOnly', 'Allow')
        $access = [System.IO.Directory]::GetAccessControl($hostHelperFolder).Access | 
                    Where-Object { $_.IdentityReference -eq $rule.IdentityReference -and $_.FileSystemRights -eq $rule.FileSystemRights -and $_.AccessControlType -eq $rule.AccessControlType -and $_.InheritanceFlags -eq $rule.InheritanceFlags }
        
        if ($access) {
            if (!$silent) {
                Write-Host -ForegroundColor Green "$myUsername has the right permissions to $hostHelperFolder"
            }
        } else {
            Write-Host -ForegroundColor Red "$myUsername does NOT have Full Control to $hostHelperFolder and all subfolders"
            if (!$Fix) {
                Write-Host -ForegroundColor Red "You need to run as administrator or you can run Check-BcContainerHelperPermissions -Fix to fix permissions"
            } else {
                Write-Host -ForegroundColor Yellow "Trying to add permissions"
                $scriptblock = {
                    Param($myUsername, $hostHelperFolder)
                    try {
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 3, 'InheritOnly', 'Allow')
                        $acl = [System.IO.Directory]::GetAccessControl($hostHelperFolder)
                        $acl.AddAccessRule($rule)
                        [System.IO.Directory]::SetAccessControl($hostHelperFolder,$acl) 
                        EXIT 0
                    } catch {
                        EXIT 1
                    }
                }
                $exitCode = (Start-Process powershell -ArgumentList "-command & {$scriptblock} -myUsername '$myUsername' -hostHelperFolder '$hostHelperFolder'" -Verb RunAs -wait -WindowStyle Hidden -PassThru).ExitCode
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
            if (!$silent) {
                Write-Host "Checking permissions to $hostsFile"
            }
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'Modify', 'Allow')
            $access = [System.IO.Directory]::GetAccessControl($hostsFile).Access | 
                        Where-Object { $_.IdentityReference -eq $rule.IdentityReference -and $_.FileSystemRights -eq $rule.FileSystemRights -and $_.AccessControlType -eq $rule.AccessControlType }
    
            if ($access) {
                if (!$silent) {
                    Write-Host -ForegroundColor Green "$myUsername has the right permissions to $hostsFile"
                }
            } else {
                Write-Host -ForegroundColor Red "$myUsername does NOT have modify permissions to $hostsFile"
                if (!$Fix) {
                    Write-Host -ForegroundColor Red "You need to run as administrator or you can run Check-BcContainerHelperPermissions -Fix to fix permissions"
                } else {
                    Write-Host -ForegroundColor Yellow "Trying to add permissions"
                    $scriptblock = {
                        Param($myUsername, $hostsFile)
                        try {
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'Modify', 'Allow')
                            $acl = [System.IO.Directory]::GetAccessControl($hostsFile)
                            $acl.AddAccessRule($rule)
                            [System.IO.Directory]::SetAccessControl($hostsFile,$acl) 
                            EXIT 0
                        } catch {
                            EXIT 1
                        }
                    }
                    $exitcode = (Start-Process powershell -ArgumentList "-command & {$scriptblock} -myUsername '$myUsername' -hostsFile '$hostsFile'" -Verb RunAs -wait -PassThru -WindowStyle Hidden).ExitCode
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
        if (!$silent) {
            Write-Host "Checking permissions to docker commands"
        }
        $npipe = ""
        $dockerOk = $true
        $pre = $errorActionPreference
        $errorActionPreference = 'Continue'
        try{
            $tempFile = [System.IO.Path]::GetTempFileName()
            $ps = docker ps 2> $tempFile
            if ($LASTEXITCODE -ne 0) {
                $dockerOk = $false
                $err = [System.IO.File]::ReadAllText($tempFile)
                Write-Host $err
                Remove-Item -Path $tempFile -ErrorAction Ignore
                $npipeStart = $err.IndexOf('\\.\pipe')
                if ($npipeStart -lt 0) {
                    $npipeStart = $err.IndexOf('//./pipe')
                }
                $npipeEnd = $err.IndexOf(': Access is denied')
                $npipe = $err.SubString($npipeStart, $npipeEnd-$npipeStart)
            }
        } catch {
            $dockerOk = $false
        }
        $errorActionPreference = $pre

        if ($dockerOk) {
            if (!$silent) {
                Write-Host -ForegroundColor Green "$myUsername has the right permissions to run docker commands"
            }
        } else {
            Write-Host -ForegroundColor Red "$myUsername does NOT have permissions to run docker commands"
            if (!$Fix) {
                Write-Host -ForegroundColor Red "You need to run as administrator or you can run Check-BcContainerHelperPermissions -Fix to fix permissions"
            } else {
                if ($npipe -eq "") {
                    Write-Host -ForegroundColor Red "Unable to determine docker deamon socket. Are you sure Docker is running and reachable?"
                } else {
                    Write-Host -ForegroundColor Yellow "Trying to add permissions"
                    $scriptblock = {
                        Param($myUsername, $npipe)
                        try {
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($myUsername,'FullControl', 'Allow')
                            $acl = [System.IO.Directory]::GetAccessControl($npipe)
                            $acl.AddAccessRule($rule)
                            [System.IO.Directory]::SetAccessControl($npipe,$acl) 
                            exit 0
                        } catch {
                            exit 1
                        }
                    }
            
                    $exitcode = (Start-Process powershell -ArgumentList "-command & {$scriptblock} -myUsername '$myUsername' -npipe '$npipe'" -Verb RunAs -wait -PassThru).ExitCode
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
Set-Alias -Name Check-NavContainerHelperPermissions -Value Check-BcContainerHelperPermissions
Export-ModuleMember -Function Check-BcContainerHelperPermissions -Alias Check-NavContainerHelperPermissions

