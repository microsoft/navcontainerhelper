﻿<# 
 .Synopsis
  Get (or create) a PSSession for a NAV/BC Container
 .Description
  Checks the session cache for an existing session. If a session exists, it will be reused.
  If no session exists, a new session will be created.
 .Parameter containerName
  Name of the container for which you want to create a session
 .Parameter silent
  Include the silent switch to avoid the welcome text
 .Example
  $session = Get-BcContainerSession -containerName bcserver
  PS C:\>Invoke-Command -Session $session -ScriptBlock { Set-NavServerInstance -ServerInstance $ServerInstance -restart }
#>
function Get-BcContainerSession {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [switch] $tryWinRmSession = ($bccontainerHelperConfig.useWinRmSession -ne 'never'),
        [switch] $alwaysUseWinRmSession = ($bccontainerHelperConfig.useWinRmSession -eq 'always'),
        [switch] $usePwsh = $bccontainerHelperConfig.usePwshForBc24,
        [switch] $silent,
        [switch] $reinit
    )

    Process {
        $newsession = $false
        $session = $null
        if ($sessions.ContainsKey($containerName)) {
            $session = $sessions[$containerName]
            try {
                $platformVersion = Invoke-Command -Session $session -ScriptBlock { [System.Version](get-item 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe').Versioninfo.FileVersion }
                if ($platformVersion.Major -ge 24 -and ($usePwsh -xor $session.ConfigurationName -eq 'PowerShell.7')) {
                    # Cannot use existing session
                    Remove-PSSession -Session $session
                    $sessions.Remove($containerName)
                    $session = $null
                }
                else {
                    if (!$reinit) {
                        return $session
                    }
                }
            }
            catch {
                Remove-PSSession -Session $session
                $sessions.Remove($containerName)
                $session = $null
            }
        }
        if (!$session) {
            [System.Version]$platformVersion = Get-BcContainerPlatformVersion -containerOrImageName $containerName
            if ($platformVersion.Major -lt 24) {
                $usePwsh = $false
            }
            $configurationName = 'Microsoft.PowerShell'
            if ($usePwsh) {
                $configurationName = 'PowerShell.7'
            }
            if ($isInsideContainer) {
                $session = New-PSSession -Credential $bcContainerHelperConfig.WinRmCredentials -ComputerName $containerName -Authentication Basic -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
            }
            elseif ($isAdministrator -and !$alwaysUseWinRmSession) {
                try {
                    $containerId = Get-BcContainerId -containerName $containerName
                    $session = New-PSSession -ContainerId $containerId -RunAsAdministrator -ErrorAction SilentlyContinue -ConfigurationName $configurationName
                }
                catch {}
            }
            if (!$session) {
                if (!($alwaysUseWinRmSession -or $tryWinRmSession)) {
                    throw "Unable to create session for container $containerName (cannot use WinRm)"

                }
                $useSSL = $bcContainerHelperConfig.useSslForWinRmSession
                $winRmPassword = "Bc$((Get-CimInstance win32_ComputerSystemProduct).UUID)!"
                $credential = New-Object PSCredential -ArgumentList 'winrm', (ConvertTo-SecureString -string $winRmPassword -AsPlainText -force)
                if ($useSSL) {
                    $sessionOption = New-PSSessionOption -Culture 'en-US' -UICulture 'en-US' -SkipCACheck -SkipCNCheck
                    $Session = New-PSSession -ConnectionUri "https://$($containerName):5986" -Credential $credential -Authentication Basic -SessionOption $sessionOption -ConfigurationName $configurationName
                }
                else {
                    $sessionOption = New-PSSessionOption -Culture 'en-US' -UICulture 'en-US'
                    $Session = New-PSSession -ConnectionUri "http://$($containerName):5985" -Credential $credential -Authentication Basic -SessionOption $sessionOption -ConfigurationName $configurationName
                }
            }
            $newsession = $true
        }
        Invoke-Command -Session $session -ScriptBlock { Param([bool]$silent)

            $ErrorActionPreference = 'Stop'
            $runPath = "c:\Run"
            $myPath = Join-Path $runPath "my"

            function Get-MyFilePath([string]$FileName)
            {
                if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
                    (Join-Path $myPath $FileName)
                } else {
                    (Join-Path $runPath $FileName)
                }
            }

            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

            . (Get-MyFilePath "prompt.ps1") -silent:$silent | Out-Null
            . (Get-MyFilePath "ServiceSettings.ps1") | Out-Null
            . (Get-MyFilePath "HelperFunctions.ps1") | Out-Null

            $txt2al = ""
            if ($roleTailoredClientFolder) {
                $txt2al = Join-Path $roleTailoredClientFolder "txt2al.exe"
                if (!(Test-Path $txt2al)) {
                    $txt2al = ""
                }
            }

            Set-Location $runPath
        } -ArgumentList $silent
        if ($newsession) {
            $sessions.Add($containerName, $session)
        }
        return $session
    }
}
Set-Alias -Name Get-NavContainerSession -Value Get-BcContainerSession
Export-ModuleMember -Function Get-BcContainerSession -Alias Get-NavContainerSession
