function Log([string]$line, [string]$color = "Gray") { 
    Write-Host -ForegroundColor $color $line
}

function Get-DefaultAdminPassword {
    if (Test-Path "$demoFolder\settings.ps1") {
        . "$demoFolder\settings.ps1"
        if (Test-Path "$demoFolder\aes.key") {
            $key = Get-Content -Path "$demoFolder\aes.key"
            ConvertTo-SecureString -String $adminPassword -Key $key
        } else {
            ConvertTo-SecureString -String $adminPassword
        }
    } else {
        Read-Host -Prompt "Please enter the admin password for the Nav Container" -AsSecureString
    }
}

function Get-DefaultVmAdminUsername {
    if (Test-Path "$demoFolder\settings.ps1") {
        . "$demoFolder\settings.ps1"
        $vmAdminUsername
    } else {
        "$env:USERNAME"
    }
}

function DockerRun {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName,
        [switch]$accept_eula,
        [switch]$accept_outdated,
        [switch]$wait,
        [string[]]$parameters
    )

    if ($accept_eula) {
        $parameters += "--env accept_eula=Y"
    }
    if ($accept_outdated) {
        $parameters += "--env accept_outdated=Y"
    }
    if (!$wait) {
        $parameters += "--detach"
    }
    $parameters += $imageName

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "docker.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = ("run "+[string]::Join(" ", $parameters))
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $output = $p.StandardOutput.ReadToEnd()
    $output += $p.StandardError.ReadToEnd()
    $output
}

function Get-NavContainerAuth {
    Param
    (
        [string]$containerName
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { 
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
    }
}

function Update-Hosts {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$hostName,
        [string]$ip
    ) 

    $hostsFile = "c:\windows\system32\drivers\etc\hosts"

    if (Test-Path $hostsFile) {
        $retry = $true
        while ($retry) {
            try {
                [System.Collections.ArrayList]$hosts = @(Get-Content -Path $hostsFile -Encoding Ascii)
                $retry = $false
            } catch {
                Start-Sleep -Seconds 1
            }
        }
    } else {
        $hosts = New-Object System.Collections.ArrayList
    }
    $ln = 0
    while ($ln -lt $hosts.Count) {
        $line = $hosts[$ln]
        $idx = $line.IndexOf('#')
        if ($idx -ge 0) {
            $line = $line.Substring(0,$idx)
        }
        $hidx = ("$line ".Replace("`t"," ")).IndexOf(" $hostName ")
        if ($hidx -ge 0) {
            $hosts.RemoveAt($ln) | Out-Null
        } else {
            $ln++
        }
    }
    if ("$ip" -ne "") {
        $hosts.Add("$ip $hostName") | Out-Null
    }
    $retry = $true
    while ($retry) {
        try {
            Set-Content -Path $hostsFile -Value $($hosts -join [Environment]::NewLine) -Encoding Ascii -Force -ErrorAction Ignore
            $retry = $false
        } catch {
            Start-Sleep -Seconds 1
        }
    }
}
