<# 
 .Synopsis
  Uses a NAV/BC Container to sign an App
 .Description
  appFile must be shared with the container
  Copies the pfxFile to the container if necessary
  Creates a session to the container and Signs the App using the provided certificate and password
 .Parameter containerName
  Name of the container in which you want to publish an app
 .Parameter appFile
  Path of the app you want to sign
 .Parameter pfxFile
  Path/Url of the certificate pfx file to use for signing
 .Parameter pfxPassword
  Password of the certificate pfx file
 .Parameter timeStampServer
  Specifies the URL of the time stamp server. Default is $bcContainerHelperConfig.timeStampServer, which defaults to http://timestamp.verisign.com/scripts/timestamp.dll
 .Example
  Sign-BcContainerApp -appFile c:\programdata\bccontainerhelper\myapp.app -pfxFile http://my.secure.url/mycert.pfx -pfxPassword $securePassword
 .Example
  Sign-BcContainerApp -appFile c:\programdata\bccontainerhelper\myapp.app -pfxFile c:\programdata\bccontainerhelper\mycert.pfx -pfxPassword $securePassword
#>
function Sign-BcContainerApp {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $appFile,
        [Parameter(Mandatory=$true)]
        [string] $pfxFile,
        [Parameter(Mandatory=$true)]
        [SecureString] $pfxPassword,
        [Parameter(Mandatory=$false)]
        [string] $timeStampServer = $bcContainerHelperConfig.timeStampServer,
        [Parameter(Mandatory=$false)]
        [string] $digestAlgorithm = $bcContainerHelperConfig.digestAlgorithm
    )

    $containerAppFile = Get-BcContainerPath -containerName $containerName -path $appFile
    if ("$containerAppFile" -eq "") {
        throw "The app ($appFile)needs to be in a folder, which is shared with the container $containerName"
    }

    $copied = $false
    if ($pfxFile.ToLower().StartsWith("http://") -or $pfxFile.ToLower().StartsWith("https://")) {
        $containerPfxFile = $pfxFile
    } else {
        $containerPfxFile = Get-BcContainerPath -containerName $containerName -path $pfxFile
        if ("$containerPfxFile" -eq "") {
            $containerPfxFile = Join-Path "c:\run" ([System.IO.Path]::GetFileName($pfxFile))
            Copy-FileToBcContainer -containerName $containerName -localPath $pfxFile -containerPath $containerPfxFile
            $copied = $true
        }
    }


    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appFile, $pfxFile, $pfxPassword, $timeStampServer, $digestAlgorithm)

        if ($pfxFile.ToLower().StartsWith("http://") -or $pfxFile.ToLower().StartsWith("https://")) {
            $pfxUrl = $pfxFile
            $pfxFile = Join-Path "c:\run" ([System.Uri]::UnescapeDataString([System.IO.Path]::GetFileName($pfxUrl).split("?")[0]))
            (New-Object System.Net.WebClient).DownloadFile($pfxUrl, $pfxFile)
            $copied = $true
        }

        if (!(Test-Path "C:\Windows\System32\msvcr120.dll")) {
            Write-Host "Downloading vcredist_x86"
            (New-Object System.Net.WebClient).DownloadFile('https://bcartifacts.azureedge.net/prerequisites/vcredist_x86.exe','c:\run\install\vcredist_x86.exe')
            Write-Host "Installing vcredist_x86"
            start-process -Wait -FilePath c:\run\install\vcredist_x86.exe -ArgumentList /q, /norestart
            Write-Host "Downloading vcredist_x64"
            (New-Object System.Net.WebClient).DownloadFile('https://bcartifacts.azureedge.net/prerequisites/vcredist_x64.exe','c:\run\install\vcredist_x64.exe')
            Write-Host "Installing vcredist_x64"
            start-process -Wait -FilePath c:\run\install\vcredist_x64.exe -ArgumentList /q, /norestart
        }

        if (Test-Path "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe") {
            $signToolExe = (get-item "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe").FullName
        } else {
            Write-Host "Downloading Signing Tools"
            $winSdkSetupExe = "c:\run\install\winsdksetup.exe"
            $winSdkSetupUrl = "https://go.microsoft.com/fwlink/p/?LinkID=2023014"
            (New-Object System.Net.WebClient).DownloadFile($winSdkSetupUrl, $winSdkSetupExe)
            Write-Host "Installing Signing Tools"
            Start-Process $winSdkSetupExe -ArgumentList "/features OptionId.SigningTools /q" -Wait
            if (!(Test-Path "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe")) {
                throw "Cannot locate signtool.exe after installation"
            }
            $signToolExe = (get-item "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe").FullName
        }

        Write-Host "Signing $appFile"
        $unsecurepassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPassword)))
        $attempt = 1
        $maxAttempts = 5
        do {
            try {
                if ($digestAlgorithm) {
                    & "$signtoolexe" @("sign", "/f", "$pfxFile", "/p","$unsecurepassword", "/fd", $digestAlgorithm, "/td", $digestAlgorithm, "/tr", "$timeStampServer", "$appFile") | Write-Host
                }
                else {
                    & "$signtoolexe" @("sign", "/f", "$pfxFile", "/p","$unsecurepassword", "/t", "$timeStampServer", "$appFile") | Write-Host
                }
                break
            } catch {
                if ($attempt -ge $maxAttempts) {
                    throw
                }
                else {
                    $seconds = [Math]::Pow(4,$attempt)
                    Write-Host "Signing failed, retrying in $seconds seconds"
                    $attempt++
                    Start-Sleep -Seconds $seconds
                }
            }
        } while ($attempt -le $maxAttempts)

        if ($copied) { 
            Remove-Item $pfxFile -Force
        }
    } -ArgumentList $containerAppFile, $containerPfxFile, $pfxPassword, $timeStampServer, $digestAlgorithm
}
Set-Alias -Name Sign-NavContainerApp -Value Sign-BcContainerApp
Export-ModuleMember -Function Sign-BcContainerApp -Alias Sign-NavContainerApp
