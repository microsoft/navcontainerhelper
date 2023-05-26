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
        [switch] $silent,
        [switch] $reinit
    )

    Process {
        $newsession = $false
        $session = $null
        if ($sessions.ContainsKey($containerName)) {
            $session = $sessions[$containerName]
            Write-Host "Found session"
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
            Write-Host "IsInsideContainer $isInsideContainer"
            Write-Host "IsPsCore $isPsCore"
            Write-Host "IsAdministrator $isAdministrator"

            if ($isInsideContainer) {
                $session = New-PSSession -Credential $bcContainerHelperConfig.WinRmCredentials -ComputerName $containerName -Authentication Basic -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
            }
            elseif (!$isAdministrator) {
                $UUID = (Get-WmiObject -Class "Win32_ComputerSystemProduct").UUID
                $credential = New-Object PSCredential -ArgumentList 'winrm', (ConvertTo-SecureString -string $UUID -AsPlainText -force)
                winrm get winrm/config | Out-Host
                Invoke-ScriptInBcContainer -containerName $containerName -useSession:$false -scriptblock { Param([PSCredential] $credential)
                    winrm get winrm/config | Out-Host
                    $winrmuser = get-localuser -name $credential.UserName -ErrorAction SilentlyContinue
                    if (!$winrmuser) {
                        $cert = New-SelfSignedCertificate -DnsName "dontcare" -CertStoreLocation Cert:\LocalMachine\My
                        winrm create winrm/config/Listener?Address=*+Transport=HTTPS ('@{Hostname="dontcare"; CertificateThumbprint="' + $cert.Thumbprint + '"}')
                        winrm set winrm/config/service/Auth '@{Basic="true"}' | Out-Null
                        Write-Host "`nCreating Container user $($credential.UserName)"
                        New-LocalUser -AccountNeverExpires -PasswordNeverExpires -FullName $credential.UserName -Name $credential.UserName -Password $credential.Password | Out-Null
                        Add-LocalGroupMember -Group administrators -Member $credential.UserName | Out-Null
                    }
                } -argumentList $credential
                $session = New-PSSession -Credential $credential -ComputerName $containerName -Authentication Basic -useSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
            }
            else {
                $containerId = Get-BcContainerId -containerName $containerName
                $session = New-PSSession -ContainerId $containerId -RunAsAdministrator
            }
            $newsession = $true
        }
        Write-Host "Initialize session"
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
