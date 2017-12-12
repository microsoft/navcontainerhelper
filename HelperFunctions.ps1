function Log([string]$line, [string]$color = "Gray") { 
    Write-Host -ForegroundColor $color $line
}

function Get-DefaultCredential {
    Param(
        [string]$Message,
        [string]$DefaultUserName
    )

    if (Test-Path "$hostHelperFolder\settings.ps1") {
        . "$hostHelperFolder\settings.ps1"
        if (Test-Path "$hostHelperFolder\aes.key") {
            $key = Get-Content -Path "$hostHelperFolder\aes.key"
            New-Object System.Management.Automation.PSCredential ($DefaultUserName, (ConvertTo-SecureString -String $adminPassword -Key $key))
        } else {
            New-Object System.Management.Automation.PSCredential ($DefaultUserName, (ConvertTo-SecureString -String $adminPassword))
        }
    } else {
        Get-Credential -username $DefaultUserName -Message $Message
    }
}

function Get-DefaultSqlCredential {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [System.Management.Automation.PSCredential]$sqlCredential = $null
    )

    $containerAuth = Get-NavContainerAuth -containerName $containerName
    if ($containerAuth -eq "NavUserPassword") {
        if (($sqlCredential -eq $null) -or ($sqlCredential -eq [System.Management.Automation.PSCredential]::Empty)) {
            $sqlCredential = Get-DefaultCredential -DefaultUserName "sa" -Message "Please enter the SQL Server System Admin credentials for container $containerName"
        }
    }
    $sqlCredential
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

