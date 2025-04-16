<# 
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
        $inspect = docker inspect $containerName | ConvertFrom-Json
        if (!($inspect.Config.Labels.psobject.Properties.Name -eq 'maintainer' -and $inspect.Config.Labels.maintainer -eq "Dynamics SMB")) {
            throw "Container $containerOrImageName is not a NAV/BC container"
        }
        [System.Version]$platformVersion = [System.Version]"$($inspect.Config.Labels.platform)"
        if ($inspect.Config.Labels.PSObject.Properties.Name -eq 'filesonly' -and $inspect.Config.Labels.filesonly -eq 'yes') {
            $tryWinRmSession = 'never'
        }
        if ($platformVersion.Major -lt 24) {
            $usePwsh = $false
        }
        $configurationName = 'Microsoft.PowerShell'
        if ($usePwsh) {
            $configurationName = 'PowerShell.7'
        }
        $cacheName = "$containerName-$configurationName"
        if ($sessions.ContainsKey($cacheName)) {
            if ($bcContainerHelperConfig.debugMode) {
                Write-Host "Session $cacheName found in cache"
            }
            $session = $sessions[$cacheName]
            try {
                Invoke-Command -Session $session -ScriptBlock { $PID } | Out-Null
                if (!$reinit) {
                    if ($bcContainerHelperConfig.debugMode) {
                        Write-Host "Session $cacheName is still valid"
                    }
                    return $session
                }
            }
            catch {
                if ($bcContainerHelperConfig.debugMode) {
                    Write-Host "Session $cacheName is not valid anymore"
                }
                $sessions.Remove($cacheName)
                $session = $null
            }
        }
        if (!$session) {
            if ($isInsideContainer) {
                if ($bcContainerHelperConfig.debugMode) {
                    Write-Host "Creating session from inside container"
                }
                $session = New-PSSession -Credential $bcContainerHelperConfig.WinRmCredentials -ComputerName $containerName -Authentication Basic -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
            }
            elseif ($isAdministrator -and !$alwaysUseWinRmSession) {
                try {
                    if ($bcContainerHelperConfig.debugMode) {
                        Write-Host "Creating $configurationName session using ContainerId"
                    }
                    $containerId = Get-BcContainerId -containerName $containerName
                    $session = New-PSSession -ContainerId $containerId -RunAsAdministrator -ErrorAction SilentlyContinue -ConfigurationName $configurationName
                }
                catch {
                    if ($bcContainerHelperConfig.debugMode) {
                        Write-Host "Error creating session using ContainerId. Error was $($_.Exception.Message)"
                    }
                }
            }
            if (!$session) {
                if (!($alwaysUseWinRmSession -or $tryWinRmSession)) {
                    throw "Unable to create session for container $containerName (cannot use WinRm)"

                }
                $useSSL = $bcContainerHelperConfig.useSslForWinRmSession
                if ($bcContainerHelperConfig.debugMode) {
                    Write-Host "Creating session using WinRm, useSSL=$useSSL"
                }
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
            if ($bcContainerHelperConfig.debugMode) {
                Write-Host "Session $cacheName created"
            }
            $sessions.Add($cacheName, $session)
        }
        return $session
    }
}
Set-Alias -Name Get-NavContainerSession -Value Get-BcContainerSession
Export-ModuleMember -Function Get-BcContainerSession -Alias Get-NavContainerSession
