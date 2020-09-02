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
        [switch]$silent,
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

    $result = $true
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


    $outtask = $null
    $errtask = $p.StandardError.ReadToEndAsync()
    $out = ""
    $err = ""
    
    do {
        if ($outtask -eq $null) {
            $outtask = $p.StandardOutput.ReadLineAsync()
        }
        $outtask.Wait(100) | Out-Null
        if ($outtask.IsCompleted) {
            $outStr = $outtask.Result
            if ($outStr -eq $null) {
                break
            }
            if (!$silent) {
                Write-Host $outStr
            }
            $out += $outStr
            $outtask = $null
            if ($outStr.StartsWith("Please login")) {
                $registry = $imageName.Split("/")[0]
                if ($registry -eq "bcinsider.azurecr.io" -or $registry -eq "bcprivate.azurecr.io") {
                    throw "You need to login to $registry prior to pulling images. Get credentials through the ReadyToGo program on Microsoft Collaborate."
                } else {
                    throw "You need to login to $registry prior to pulling images."
                }
            }
        } elseif ($outtask.IsCanceled) {
            break
        } elseif ($outtask.IsFaulted) {
            break
        }
    } while(!($p.HasExited))
    
    $err = $errtask.Result
    $p.WaitForExit();

    if ($p.ExitCode -ne 0) {
        $result = $false
        if (!$silent) {
            $out = $out.Trim()
            $err = $err.Trim()
            if ($command -eq "run" -and "$out" -ne "") {
                Docker rm $out -f
            }
            $errorMessage = ""
            if ("$err" -ne "") {
                $errorMessage += "$err`r`n"
                if ($err.Contains("authentication required")) {
                    $registry = $imageName.Split("/")[0]
                    if ($registry -eq "bcinsider.azurecr.io" -or $registry -eq "bcprivate.azurecr.io") {
                        $errorMessage += "You need to login to $registry prior to pulling images. Get credentials through the ReadyToGo program on Microsoft Collaborate.`r`n"
                    } else {
                        $errorMessage += "You need to login to $registry prior to pulling images.`r`n"
                    }
                }
            }
            $errorMessage += "ExitCode: "+$p.ExitCode + "`r`nCommandline: docker $arguments"
            Write-Error -Message $errorMessage
        }
    }
    $result
}

function Get-NavContainerAuth {
    Param
    (
        [string]$containerName
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { 
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
    }
}

function Check-BcContainerName {
    Param
    (
        [string]$containerName = ""
    )

    if ($containerName -eq "") {
        throw "Container name cannot be empty"
    }

    if ($containerName.Length -gt 15) {
        Write-Host "WARNING: Container name should not exceed 15 characters"
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

function AssumeNavContainer {
    Param
    (
        [string]$containerOrImageName = "",
        [string]$functionName = ""
    )

    $inspect = docker inspect $containerOrImageName | ConvertFrom-Json
    if ($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -eq 0 -or $inspect.Config.Labels.maintainer -ne "Dynamics SMB") {
        throw "Container $containerOrImageName is not a Business Central container"
    }
    [System.Version]$version = $inspect.Config.Labels.version

    if ("$functionName" -eq "") {
        $functionName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
    }
    if ($version.Major -ge 15) {
        throw "Container $containerOrImageName does not support the function $functionName"
    }
}

function TestSasToken {
    Param
    (
        [string] $sasToken
    )

    if ($sasToken.Contains('?')) {
        $se = $sasToken.Split('?')[1].Split('&') | Where-Object { $_.StartsWith('se=') } | % { [Uri]::UnescapeDataString($_.Substring(3))}
        $st = $sasToken.Split('?')[1].Split('&') | Where-Object { $_.StartsWith('st=') } | % { [Uri]::UnescapeDataString($_.Substring(3))}
        if ($st) {
            if ([DateTime]::Now -lt [DateTime]$st) {
                Write-Host "ERROR: The sas token provided isn't valid before $(([DateTime]$st).ToString())"
            }
        }
        if ($se) {
            if ([DateTime]::Now -gt [DateTime]$se) {
                Write-Host "ERROR: The sas token provided expired on $(([DateTime]$se).ToString())"
            }
            elseif ([DateTime]::Now.AddDays(7) -gt [DateTime]$se) {
                $span = ([DateTime]$se).Subtract([DateTime]::Now)
                Write-Host "WARNING: The sas token provided will expire on $(([DateTime]$se).ToString())"
            }
        }
    }
}

function Expand-7zipArchive {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Path,
        [string] $DestinationPath
    )

    $7zipPath = "$env:ProgramFiles\7-Zip\7z.exe"

    $use7zip = $false
    if ($bcContainerHelperConfig.use7zipIfAvailable -and (Test-Path -Path $7zipPath -PathType Leaf)) {
        try {
            $use7zip = [decimal]::Parse([System.Diagnostics.FileVersionInfo]::GetVersionInfo($7zipPath).FileVersion, [System.Globalization.CultureInfo]::InvariantCulture) -ge 19
        }
        catch {
            $use7zip = $false
        }
    }

    if ($use7zip) {
        Write-Host "using 7zip"
        Set-Alias -Name 7z -Value $7zipPath
        $command = '7z x "{0}" -o"{1}" -aoa -r' -f $Path,$DestinationPath
        Invoke-Expression -Command $command | Out-Null
    } else {
        Write-Host "using Expand-Archive"
        Expand-Archive -Path $Path -DestinationPath "$DestinationPath" -Force
    }
}

function GetTestToolkitApps {
    Param(
        [string] $containerName,
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [switch] $includePerformanceToolkit
    )

    Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($includeTestLibrariesOnly, $includeTestFrameworkOnly, $includePerformanceToolkit)
    
        # Add Test Framework
        $apps = @(get-childitem -Path "C:\Applications\TestFramework\TestLibraries\*.*" -recurse -filter "*.app")
        $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestRunner\*.*" -recurse -filter "*.app")
    

        if (!$includeTestFrameworkOnly) {
            
            # Add Test Libraries
            $apps += "Microsoft_System Application Test Library.app", "Microsoft_Tests-TestLibraries.app" | % {
                @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
            }

            if (!$includeTestLibrariesOnly) {

                # Add Tests
                $apps += @(get-childitem -Path "C:\Applications\*.*" -recurse -filter "Microsoft_Tests-*.app") | Where-Object { $_ -notlike "*\Microsoft_Tests-TestLibraries.app" -and $_ -notlike "*\Microsoft_Tests-Marketing.app" -and $_ -notlike "*\Microsoft_Tests-SINGLESERVER.app" }
            }
        }

        if ($includePerformanceToolkit) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*.app")
        }

        $apps | % {
            $appFile = Get-ChildItem -path "c:\applications.*\*.*" -recurse -filter ($_.Name).Replace(".app","_*.app")
            if (!($appFile)) {
                $appFile = $_
            }
            $appFile
        }
    } -argumentList $includeTestLibrariesOnly, $includeTestFrameworkOnly, $includePerformanceToolkit
}

