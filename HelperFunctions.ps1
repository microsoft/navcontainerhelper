function Log([string]$line, [string]$color = "Gray") { 
    Write-Host -ForegroundColor $color $line
}

function Get-DefaultCredential {
    Param(
        [string]$Message,
        [string]$DefaultUserName,
        [switch]$doNotAskForCredential
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
        if (!$doNotAskForCredential) {
            Get-Credential -username $DefaultUserName -Message $Message
        }
    }
}

function Get-DefaultSqlCredential {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [System.Management.Automation.PSCredential]$sqlCredential = $null,
        [switch]$doNotAskForCredential
    )

    if ($sqlCredential -eq $null) {
        $containerAuth = Get-NavContainerAuth -containerName $containerName
        if ($containerAuth -ne "Windows") {
            $sqlCredential = Get-DefaultCredential -DefaultUserName "" -Message "Please enter the SQL Server System Admin credentials for container $containerName" -doNotAskForCredential:$doNotAskForCredential
        }
    }
    $sqlCredential
}

function DockerDo {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName,
        [ValidateSet('run','start','pull','restart','stop')]
        [string]$command = "run",
        [switch]$accept_eula,
        [switch]$accept_outdated,
        [switch]$detach,
        [string[]]$parameters = @()
    )

    if ($accept_eula) {
        $parameters += "--env accept_eula=Y"
    }
    if ($accept_outdated) {
        $parameters += "--env accept_outdated=Y"
    }
    if ($detach) {
        $parameters += "--detach"
    }
    $arguments = ("$command "+[string]::Join(" ", $parameters)+" $imageName")

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "docker.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $output = $p.StandardOutput.ReadToEnd()
    $error = $p.StandardError.ReadToEnd()
    if ($p.ExitCode -eq 0) {
        return $true
    } else {
        if ("$output".Trim() -ne "") {
            Log $output
        }
        $errorMessage = ""
        if ("$error".Trim() -ne "") {
            $errorMessage += $error + "`r`n"
        }
        $errorMessage += "Commandline: docker $arguments"
        Write-Error -Message $errorMessage
        return $false
    }
}

function Get-NavContainerAuth {
    Param
    (
        [string]$containerName
    )

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { 
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
    }
}

function Check-NavContainerName {
    Param
    (
        [string]$containerName = ""
    )

    if ($containerName -eq "") {
        throw "Container name cannot be empty"
    }

    if ($containerName.Length -gt 15) {
        throw "Container name should not exceed 15 characters"
    }

    $first = $containerName.ToLowerInvariant()[0]
    if ($first -lt "a" -or $first -gt "z") {
        throw "Container name should start with a letter (a-z)"
    }

    $containerName.ToLowerInvariant().ToCharArray() | ForEach-Object {
        if (($_ -lt "a" -or $_ -gt "z") -and ($_ -lt "0" -or $_ -gt "9") -and ($_ -ne "-")) {
            throw "Container name contains invalid characters. Allowed characters are letters (a-z), numbers (0-9) and dashes (-)"
        }
    }
}
