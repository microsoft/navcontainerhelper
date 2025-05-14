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
  Specifies the URL of the time stamp server. Default is $bcContainerHelperConfig.timeStampServer, which defaults to http://timestamp.digicert.com
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
        [string] $digestAlgorithm = $bcContainerHelperConfig.digestAlgorithm,
        [switch] $importCertificate
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $containerAppFile = Get-BcContainerPath -containerName $containerName -path $appFile
    if ("$containerAppFile" -eq "") {
        throw "The app ($appFile)needs to be in a folder, which is shared with the container $containerName"
    }

    $sharedPfxFile = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\my\$([GUID]::NewGuid().ToString()).pfx"
    $removeSharedPfxFile = $true
    if ($pfxFile -like "https://*" -or $pfxFile -like "http://*") {
        Write-Host "Downloading certificate file to container"
        Download-File -sourceUrl $pfxFile -destinationFile $sharedPfxFile
    }
    else {
        if (Get-BcContainerPath -containerName $containerName -path $pfxFile) {
            $sharedPfxFile = $pfxFile
            $removeSharedPfxFile = $false
        }
        else {
            Write-Host "Copying certificate file to container"
            Copy-Item -Path $pfxFile -Destination $sharedPfxFile -Force
        }
    }

    try {
        TestPfxCertificate -pfxFile $sharedPfxFile -pfxPassword $pfxPassword -certkind "Codesign"

        Invoke-ScriptInBcContainer -containerName $containerName -useSession:$false -ScriptBlock { Param($appFile, $pfxFile, $pfxPassword, $timeStampServer, $digestAlgorithm, $importCertificate)

            function GetExtendedErrorMessage {
                Param(
                    $errorRecord
                )
            
                $exception = $errorRecord.Exception
                $message = $exception.Message
            
                try {
                    $errorDetails = $errorRecord.ErrorDetails | ConvertFrom-Json
                    $message += " $($errorDetails.error)`r`n$($errorDetails.error_description)"
                }
                catch {}
                try {
                    if ($exception -is [System.Management.Automation.MethodInvocationException]) {
                        $exception = $exception.InnerException
                    }
                    $webException = [System.Net.WebException]$exception
                    $webResponse = $webException.Response
                    try {
                        if ($webResponse.StatusDescription) {
                            $message += "`r`n$($webResponse.StatusDescription)"
                        }
                    } catch {}
                    $reqstream = $webResponse.GetResponseStream()
                    $sr = new-object System.IO.StreamReader $reqstream
                    $result = $sr.ReadToEnd()
                    try {
                        $json = $result | ConvertFrom-Json
                        $message += "`r`n$($json.Message)"
                    }
                    catch {
                        $message += "`r`n$result"
                    }
                    try {
                        $correlationX = $webResponse.GetResponseHeader('ms-correlation-x')
                        if ($correlationX) {
                            $message += " (ms-correlation-x = $correlationX)"
                        }
                    }
                    catch {}
                }
                catch{}
                $message
            }

            if ($importCertificate) {
                Import-PfxCertificate -FilePath $pfxFile -Password $pfxPassword -CertStoreLocation "cert:\localMachine\root" | Out-Null
                Import-PfxCertificate -FilePath $pfxFile -Password $pfxPassword -CertStoreLocation "cert:\localMachine\my" | Out-Null
            }
    
            if (!(Test-Path "C:\Windows\System32\msvcr120.dll")) {
                Write-Host "Downloading vcredist_x86"
                (New-Object System.Net.WebClient).DownloadFile('https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/prerequisites/vcredist_x86.exe','c:\run\install\vcredist_x86.exe')
                Write-Host "Installing vcredist_x86"
                start-process -Wait -FilePath c:\run\install\vcredist_x86.exe -ArgumentList /q, /norestart
                Write-Host "Downloading vcredist_x64"
                (New-Object System.Net.WebClient).DownloadFile('https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/prerequisites/vcredist_x64.exe','c:\run\install\vcredist_x64.exe')
                Write-Host "Installing vcredist_x64"
                start-process -Wait -FilePath c:\run\install\vcredist_x64.exe -ArgumentList /q, /norestart
            }

            if (!(Test-Path "C:\Windows\System32\vcruntime140_1.dll")) {
                Write-Host "Downloading vcredist_x64 (version 140)"
                (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/vs/17/release/vc_redist.x64.exe','c:\run\install\vcredist_x64-140.exe')
                Write-Host "Installing vcredist_x64 (version 140)"
                start-process -Wait -FilePath c:\run\install\vcredist_x64-140.exe -ArgumentList /q, /norestart
            }
    
            if (Test-Path "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe") {
                $signToolExe = (get-item "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe").FullName
            } else {
                Write-Host "Downloading Signing Tools"
                $winSdkSetupExe = "c:\run\install\winsdksetup.exe"
                $winSdkSetupUrl = "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/prerequisites/winsdksetup.exe"
                (New-Object System.Net.WebClient).DownloadFile($winSdkSetupUrl,$winSdkSetupExe)
                Write-Host "Installing Signing Tools"
                Start-Process $winSdkSetupExe -ArgumentList "/features OptionId.SigningTools /q" -Wait
                if (!(Test-Path "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe")) {
                    throw "Cannot locate signtool.exe after installation"
                }
                $signToolExe = (get-item "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\SignTool.exe").FullName
            }

            Write-Host "Signing $appFile"
            $unsecurepassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPassword)))
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
        } -ArgumentList $containerAppFile, (Get-BcContainerPath -containerName $containerName -path $sharedPfxFile), $pfxPassword, $timeStampServer, $digestAlgorithm, $importCertificate
    }
    finally {
        if ($removeSharedPfxFile -and (Test-Path $sharedPfxFile)) {
            Remove-Item -Path $sharedPfxFile -Force
        }
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Sign-NavContainerApp -Value Sign-BcContainerApp
Export-ModuleMember -Function Sign-BcContainerApp -Alias Sign-NavContainerApp
