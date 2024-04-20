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
        [switch] $tryWinRmSession = $bccontainerHelperConfig.tryWinRmSession,
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
                Invoke-Command -Session $session -ScriptBlock { $true } | Out-Null
                if (!$reinit) { return $session }
            }
            catch {
                Remove-PSSession -Session $session
                $sessions.Remove($containerName)
                $session = $null
            }
        }
        if (!$session) {
            [System.Version]$platformVersion = Get-BcContainerPlatformVersion -containerOrImageName $containerName
            if ($platformVersion -lt [System.Version]"24.0.0.0") {
                $usePwsh = $false
            }
            $configurationName = 'Microsoft.PowerShell'
            if ($usePwsh) {
                $configurationName = 'PowerShell.7'
            }
            if ($isInsideContainer) {
                $session = New-PSSession -Credential $bcContainerHelperConfig.WinRmCredentials -ComputerName $containerName -Authentication Basic -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
            }
            elseif ($isAdministrator) {
                try {
                    $containerId = Get-BcContainerId -containerName $containerName
                    $session = New-PSSession -ContainerId $containerId -RunAsAdministrator -ErrorAction SilentlyContinue -ConfigurationName $configurationName
                }
                catch {}
            }
            if (!$session) {
                if (!$tryWinRmSession) {
                    throw "Unable to create a session for container $containerName (tryWinRmSession is false)"
                }
                $useSSL = $bcContainerHelperConfig.useSslForWinRm
                $UUID = (Get-CimInstance win32_ComputerSystemProduct).UUID
                $credential = New-Object PSCredential -ArgumentList 'winrm', (ConvertTo-SecureString -string $UUID -AsPlainText -force)
                Invoke-ScriptInBcContainer -containerName $containerName -useSession:$false -scriptblock { Param([PSCredential] $credential, [bool] $useSSL, [string] $containerName)
                    [xml]$conf = winrm get winrm/config/service -format:pretty
                    if ($useSSL) {
                        [xml]$listeners = winrm enumerate winrm/config/listener -format:pretty
                        if (!($listeners.Results.Listener.port -eq 5986)) {
                            Write-Host "Setup self-signed certificate for container $containerName"
                            $cert = New-SelfSignedCertificate -CertStoreLocation cert:\localmachine\my -DnsName $containerName -NotBefore (get-date).AddDays(-1) -NotAfter (get-date).AddYears(5) -Provider "Microsoft RSA SChannel Cryptographic Provider" -KeyLength 2048
                            winrm create winrm/config/Listener?Address=*+Transport=HTTPS ("@{Hostname=""$containerName""; CertificateThumbprint=""$($cert.Thumbprint)""}") | Out-Null
                        }
                    }
                    else {
                        if ($conf.Service.AllowUnencrypted -eq 'false') {
                            Write-Host "Allow unencrypted communication to container $containerName"
                            winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
                        }
                    }
                    $winrmuser = get-localuser -name $credential.UserName -ErrorAction SilentlyContinue
                    if (!$winrmuser) {
                        if ($conf.Service.Auth.Basic -eq 'false') {
                            Write-Host "Enable Basic authentication for container $containerName"
                            winrm set winrm/config/service/Auth '@{Basic="true"}' | Out-Null
                        }
                        Write-Host "Creating Container user $($credential.UserName)"
                        New-LocalUser -AccountNeverExpires -PasswordNeverExpires -FullName $credential.UserName -Name $credential.UserName -Password $credential.Password | Out-Null
                        Add-LocalGroupMember -Group administrators -Member $credential.UserName | Out-Null
                    }
                } -argumentList $credential, $useSSL, $containerName
                if ($useSSL) {
                    $sessionOption = New-PSSessionOption -Culture 'en-US' -UICulture 'en-US' -SkipCACheck -SkipCNCheck
                    $Session = New-PSSession -ConnectionUri "https://$($containerName):5986" -Credential $credential -Authentication Basic -SessionOption $sessionOption -ConfigurationName $configurationName
                }
                else {
                    [xml]$conf = winrm get winrm/config/client -format:pretty
                    $trustedHosts = $conf.Client.TrustedHosts.Split(',')
                    $isTrusted = $trustedHosts | Where-Object { $containerName -like $_ }
                    if (!($isTrusted)) {
                        if (!$isAdministrator) {
                            throw "$containerName os not a trusted host. You need to get an administrator to add $containerName to the trusted winrm hosts on your machine"
                        }
                        Write-Host "Adding $containerName to trusted hosts ($($trustedHosts -join ',')))"
                        $trustedHosts += $containerName
                        winrm set winrm/config/client "@{TrustedHosts=""$($trustedHosts -join ',')""}" | Out-Null
                    }
                    if ($conf.Client.AllowUnencrypted -eq 'false') {
                        Write-Host "Allow unencrypted communication"
                        winrm set winrm/config/client '@{AllowUnencrypted="true"}' | Out-Null
                    }
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
