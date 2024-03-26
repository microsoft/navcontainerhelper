$useTimeOutWebClient = $false
if ($PSVersionTable.PSVersion -lt "6.0.0" -or $useTimeOutWebClient) {
    $timeoutWebClientCode = @"
	using System.Net;
 
	public class TimeoutWebClient : WebClient
	{
        int theTimeout;

        public TimeoutWebClient(int timeout)
        {
            theTimeout = timeout;
        }

		protected override WebRequest GetWebRequest(System.Uri address)
		{
			WebRequest request = base.GetWebRequest(address);
			if (request != null)
			{
				request.Timeout = theTimeout;
			}
			return request;
		}
 	}
"@;
if (-not ([System.Management.Automation.PSTypeName]"TimeoutWebClient").Type) {
    Add-Type -TypeDefinition $timeoutWebClientCode -Language CSharp -WarningAction SilentlyContinue | Out-Null
    $useTimeOutWebClient = $true
}
}

$sslCallbackCode = @"
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class SslVerification
{
	public static bool DisabledServerCertificateValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
	public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = DisabledServerCertificateValidationCallback; }
	public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
    public static void DisableSsl(System.Net.Http.HttpClientHandler handler) { handler.ServerCertificateCustomValidationCallback = DisabledServerCertificateValidationCallback; }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type) {
    if ($isPsCore) {
        Add-Type -TypeDefinition $sslCallbackCode -Language CSharp -WarningAction SilentlyContinue | Out-Null
    }
    else {
        Add-Type -TypeDefinition $sslCallbackCode -Language CSharp -ReferencedAssemblies @('System.Net.Http') -WarningAction SilentlyContinue | Out-Null
    }
}

function Get-DefaultCredential {
    Param(
        [string]$Message,
        [string]$DefaultUserName,
        [switch]$doNotAskForCredential
    )

    if (Test-Path "$($bcContainerHelperConfig.hostHelperFolder)\settings.ps1") {
        . "$($bcContainerHelperConfig.hostHelperFolder)\settings.ps1"
        if (Test-Path "$($bcContainerHelperConfig.hostHelperFolder)\aes.key") {
            $key = Get-Content -Path "$($bcContainerHelperConfig.hostHelperFolder)\aes.key"
            New-Object System.Management.Automation.PSCredential ($DefaultUserName, (ConvertTo-SecureString -String $adminPassword -Key $key))
        }
        else {
            New-Object System.Management.Automation.PSCredential ($DefaultUserName, (ConvertTo-SecureString -String $adminPassword))
        }
    }
    else {
        if (!$doNotAskForCredential) {
            Get-Credential -username $DefaultUserName -Message $Message
        }
    }
}

function Get-DefaultSqlCredential {
    Param(
        [Parameter(Mandatory = $true)]
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

function CmdDo {
    Param(
        [string] $command = "",
        [string] $arguments = "",
        [switch] $silent,
        [switch] $returnValue,
        [string] $inputStr = "",
        [string] $messageIfCmdNotFound = ""
    )

    $oldNoColor = "$env:NO_COLOR"
    $env:NO_COLOR = "Y"
    $oldEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $command
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        if ($inputStr) {
            $pinfo.RedirectStandardInput = $true
        }
        $pinfo.WorkingDirectory = Get-Location
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $arguments
        $pinfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        if ($inputStr) {
            $p.StandardInput.WriteLine($inputStr)
            $p.StandardInput.Close()
        }
        $outtask = $p.StandardOutput.ReadToEndAsync()
        $errtask = $p.StandardError.ReadToEndAsync()
        $p.WaitForExit();

        $message = $outtask.Result
        $err = $errtask.Result

        if ("$err" -ne "") {
            $message += "$err"
        }
        
        $message = $message.Trim()

        if ($p.ExitCode -eq 0) {
            if (!$silent) {
                Write-Host $message
            }
            if ($returnValue) {
                $message.Replace("`r", "").Split("`n")
            }
        }
        else {
            $message += "`n`nExitCode: " + $p.ExitCode + "`nCommandline: $command $arguments"
            throw $message
        }
    }
    catch [System.ComponentModel.Win32Exception] {
        if ($_.Exception.NativeErrorCode -eq 2) {
            if ($messageIfCmdNotFound) {
                throw $messageIfCmdNotFound
            }
            else {
                throw "Command $command not found, you might need to install that command."
            }
        }
        else {
            throw
        }
    }
    finally {
        try { [Console]::OutputEncoding = $oldEncoding } catch {}
        $env:NO_COLOR = $oldNoColor
    }
}

function DockerDo {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$imageName,
        [ValidateSet('run', 'start', 'pull', 'restart', 'stop', 'rmi','build')]
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
    $arguments = ("$command " + [string]::Join(" ", $parameters) + " $imageName")
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
                }
                else {
                    throw "You need to login to $registry prior to pulling images."
                }
            }
        }
        elseif ($outtask.IsCanceled) {
            break
        }
        elseif ($outtask.IsFaulted) {
            break
        }
    } while (!($p.HasExited))
    
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
                    }
                    else {
                        $errorMessage += "You need to login to $registry prior to pulling images.`r`n"
                    }
                }
            }
            $errorMessage += "ExitCode: " + $p.ExitCode + "`r`nCommandline: docker $arguments"
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
        [string] $url
    )

    $sasToken = "?$("$($url)?".Split('?')[1])"
    if ($sasToken -eq '?') {
        # No SAS token in URL
        return
    }

    try {
        $se = $sasToken.Split('?')[1].Split('&') | Where-Object { $_.StartsWith('se=') } | ForEach-Object { [Uri]::UnescapeDataString($_.Substring(3)) }
        $st = $sasToken.Split('?')[1].Split('&') | Where-Object { $_.StartsWith('st=') } | ForEach-Object { [Uri]::UnescapeDataString($_.Substring(3)) }
        $sv = $sasToken.Split('?')[1].Split('&') | Where-Object { $_.StartsWith('sv=') } | ForEach-Object { [Uri]::UnescapeDataString($_.Substring(3)) }
        $sig = $sasToken.Split('?')[1].Split('&') | Where-Object { $_.StartsWith('sig=') } | ForEach-Object { [Uri]::UnescapeDataString($_.Substring(4)) }
        if ($sv -ne '2021-10-04' -or $sig -eq '' -or $se -eq '' -or $st -eq '') {
            throw "Wrong format"
        }
        if ([DateTime]::Now -lt [DateTime]$st) {
            Write-Host "::ERROR::The sas token provided isn't valid before $(([DateTime]$st).ToString())"
        }
        if ([DateTime]::Now -gt [DateTime]$se) {
            Write-Host "::ERROR::The sas token provided expired on $(([DateTime]$se).ToString())"
        }
        elseif ([DateTime]::Now.AddDays(14) -gt [DateTime]$se) {
            Write-Host "::WARNING::The sas token provided will expire on $(([DateTime]$se).ToString())"
        }
    }
    catch {
        $message = $_.ToString()
        throw "The sas token provided is not valid, error message was: $message"
    }
}

function Expand-7zipArchive {
    Param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [string] $DestinationPath,
        [switch] $use7zipIfAvailable = $bcContainerHelperConfig.use7zipIfAvailable,
        [switch] $silent
    )

    $7zipPath = "$env:ProgramFiles\7-Zip\7z.exe"
    $use7zip = $false
    if ($use7zipIfAvailable -and (Test-Path -Path $7zipPath -PathType Leaf)) {
        try {
            $use7zip = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($7zipPath).FileMajorPart -ge 19
        }
        catch {
            $use7zip = $false
        }
    }

    if ($use7zip) {
        if (!$silent) { Write-Host "using 7zip" }
        Set-Alias -Name 7z -Value $7zipPath
        $command = '7z x "{0}" -o"{1}" -aoa -r' -f $Path, $DestinationPath
        $global:LASTEXITCODE = 0
        Invoke-Expression -Command $command | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Error $LASTEXITCODE extracting $path"
        }
    }
    else {
        if (!$silent) { Write-Host "using Expand-Archive" }
        if ([System.IO.Path]::GetExtension($path) -eq '.zip') {
            Expand-Archive -Path $Path -DestinationPath "$DestinationPath" -Force
        }
        else {
            $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid().ToString()).zip"
            Copy-Item -Path $Path -Destination $tempZip -Force
            try {
                Expand-Archive -Path $tempZip -DestinationPath "$DestinationPath" -Force
            }
            finally {
                Remove-Item -Path $tempZip -Force
            }
        }
    }
}

function GetTestToolkitApps {
    Param(
        [string] $containerName,
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [switch] $includeTestRunnerOnly,
        [switch] $includePerformanceToolkit
    )

    Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($includeTestLibrariesOnly, $includeTestFrameworkOnly, $includeTestRunnerOnly, $includePerformanceToolkit)
    
        $version = [Version](Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe").VersionInfo.FileVersion

        # Add Test Framework
        $apps = @()
        if (($version -ge [Version]"19.0.0.0") -and (Test-Path 'C:\Applications\TestFramework\TestLibraries\permissions mock')) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestLibraries\permissions mock\*.*" -recurse -filter "*.app")
        }
        $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestRunner\*.*" -recurse -filter "*.app")

        if (!$includeTestRunnerOnly) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestLibraries\*.*" -recurse -filter "*.app")

            if (!$includeTestFrameworkOnly) {
                # Add Test Libraries
                $apps += "Microsoft_System Application Test Library.app", "Microsoft_Business Foundation Test Libraries.app", "Microsoft_Tests-TestLibraries.app" | ForEach-Object {
                    @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
                }
    
                if (!$includeTestLibrariesOnly) {
                    # Add Tests
                    if ($version -ge [Version]"18.0.0.0") {
                        $apps += "Microsoft_System Application Test.app", "Microsoft_Business Foundation Tests.app" | ForEach-Object {
                            @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
                        }
                    }
                    $apps += @(get-childitem -Path "C:\Applications\*.*" -recurse -filter "Microsoft_Tests-*.app") | Where-Object { $_ -notlike "*\Microsoft_Tests-TestLibraries.app" -and ($version.Major -ge 17 -or ($_ -notlike "*\Microsoft_Tests-Marketing.app")) -and $_ -notlike "*\Microsoft_Tests-SINGLESERVER.app" }
                }
            }
        }

        if ($includePerformanceToolkit) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*Toolkit.app")
            if (!$includeTestFrameworkOnly) {
                $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*.app" -exclude "*Toolkit.app")
            }
        }

        $apps | ForEach-Object {
            $appFile = Get-ChildItem -path "c:\applications.*\*.*" -recurse -filter ($_.Name).Replace(".app", "_*.app")
            if (!($appFile)) {
                $appFile = $_
            }
            $appFile.FullName
        }
    } -argumentList $includeTestLibrariesOnly, $includeTestFrameworkOnly, $includeTestRunnerOnly, $includePerformanceToolkit
}

function GetExtendedErrorMessage {
    Param(
        $errorRecord
    )

    $exception = $errorRecord.Exception
    $message = $exception.Message

    try {
        if ($errorRecord.ErrorDetails) {
            $errorDetails = $errorRecord.ErrorDetails | ConvertFrom-Json
            $message += " $($errorDetails.error)`r`n$($errorDetails.error_description)"
        }
    }
    catch {}
    try {
        if ($exception -is [System.Management.Automation.MethodInvocationException]) {
            $exception = $exception.InnerException
        }
        if ($exception -is [System.Net.Http.HttpRequestException]) {
            $message += "`r`n$($exception.Message)"
            if ($exception.InnerException) {
                if ($exception.InnerException -and $exception.InnerException.Message) {
                    $message += "`r`n$($exception.InnerException.Message)"
                }
            }

        }
        else {
            $webException = [System.Net.WebException]$exception
            $webResponse = $webException.Response
            try {
                if ($webResponse.StatusDescription) {
                    $message += "`r`n$($webResponse.StatusDescription)"
                }
            }
            catch {}
            $reqstream = $webResponse.GetResponseStream()
            $sr = new-object System.IO.StreamReader $reqstream
            $result = $sr.ReadToEnd()
        }
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
    catch {}
    $message
}

function CopyAppFilesToFolder {
    Param(
        $appFiles,
        [string] $folder
    )

    if ($appFiles -is [String]) {
        if (!(Test-Path $appFiles)) {
            $appFiles = @($appFiles.Split(',').Trim() | Where-Object { $_ })
        }
    }
    if (!(Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory | Out-Null
    }
    $appFiles | Where-Object { $_ } | ForEach-Object {
        $appFile = $_
        if ($appFile -like "http://*" -or $appFile -like "https://*") {
            $appUrl = $appFile
            $appFileFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            $appFile = Join-Path $appFileFolder ([Uri]::UnescapeDataString([System.IO.Path]::GetFileName($appUrl.Split('?')[0])))
            Download-File -sourceUrl $appUrl -destinationFile $appFile
            CopyAppFilesToFolder -appFile $appFile -folder $folder
            if (Test-Path $appFileFolder) {
                Remove-Item -Path $appFileFolder -Force -Recurse
            }
        }
        elseif (Test-Path $appFile -PathType Container) {
            get-childitem $appFile -Filter '*.app' -Recurse | ForEach-Object {
                $destFile = Join-Path $folder $_.Name
                if (Test-Path $destFile) {
                    Write-Host -ForegroundColor Yellow "::WARNING::$([System.IO.Path]::GetFileName($destFile)) already exists, it looks like you have multiple app files with the same name. App filenames must be unique."
                }
                Copy-Item -Path $_.FullName -Destination $destFile -Force
                $destFile
            }
        }
        elseif (Test-Path $appFile -PathType Leaf) {
            Get-ChildItem $appFile | ForEach-Object {
                $appFile = $_.FullName
                if ([string]::new([char[]](Get-Content $appFile @byteEncodingParam -TotalCount 2)) -eq "PK") {
                    $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
                    $copied = $false
                    try {
                        if ($appFile -notlike "*.zip") {
                            $orgAppFile = $appFile
                            $appFile = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.IO.Path]::GetFileName($orgAppFile)).zip"
                            Copy-Item $orgAppFile $appFile
                            $copied = $true
                        }
                        Expand-Archive $appfile -DestinationPath $tmpFolder -Force
                        Get-ChildItem -Path $tmpFolder -Recurse | Where-Object { $_.Name -like "*.app" -or $_.Name -like "*.zip" } | ForEach-Object {
                            CopyAppFilesToFolder -appFile $_.FullName -folder $folder
                        }
                    }
                    finally {
                        Remove-Item -Path $tmpFolder -Recurse -Force
                        if ($copied) { Remove-Item -Path $appFile -Force }
                    }
                }
                else {
                    $destFile = Join-Path $folder "$([System.IO.Path]::GetFileNameWithoutExtension($appFile)).app"
                    if (Test-Path $destFile) {
                        Write-Host -ForegroundColor Yellow "::WARNING::$([System.IO.Path]::GetFileName($destFile)) already exists, it looks like you have multiple app files with the same name. App filenames must be unique."
                    }
                    Copy-Item -Path $appFile -Destination $destFile -Force
                    $destFile
                }
            }
        }
        else {
            Write-Host -ForegroundColor Red "::WARNING::File not found: $appFile"
        }
    }
}

function getCountryCode {
    Param(
        [string] $countryCode
    )

    $countryCodes = @{
        "Afghanistan"                                  = "AF"
        "Åland Islands"                                = "AX"
        "Albania"                                      = "AL"
        "Algeria"                                      = "DZ"
        "American Samoa"                               = "AS"
        "AndorrA"                                      = "AD"
        "Angola"                                       = "AO"
        "Anguilla"                                     = "AI"
        "Antarctica"                                   = "AQ"
        "Antigua and Barbuda"                          = "AG"
        "Argentina"                                    = "AR"
        "Armenia"                                      = "AM"
        "Aruba"                                        = "AW"
        "Australia"                                    = "AU"
        "Austria"                                      = "AT"
        "Azerbaijan"                                   = "AZ"
        "Bahamas"                                      = "BS"
        "Bahrain"                                      = "BH"
        "Bangladesh"                                   = "BD"
        "Barbados"                                     = "BB"
        "Belarus"                                      = "BY"
        "Belgium"                                      = "BE"
        "Belize"                                       = "BZ"
        "Benin"                                        = "BJ"
        "Bermuda"                                      = "BM"
        "Bhutan"                                       = "BT"
        "Bolivia"                                      = "BO"
        "Bosnia and Herzegovina"                       = "BA"
        "Botswana"                                     = "BW"
        "Bouvet Island"                                = "BV"
        "Brazil"                                       = "BR"
        "British Indian Ocean Territory"               = "IO"
        "Brunei Darussalam"                            = "BN"
        "Bulgaria"                                     = "BG"
        "Burkina Faso"                                 = "BF"
        "Burundi"                                      = "BI"
        "Cambodia"                                     = "KH"
        "Cameroon"                                     = "CM"
        "Canada"                                       = "CA"
        "Cape Verde"                                   = "CV"
        "Cayman Islands"                               = "KY"
        "Central African Republic"                     = "CF"
        "Chad"                                         = "TD"
        "Chile"                                        = "CL"
        "China"                                        = "CN"
        "Christmas Island"                             = "CX"
        "Cocos (Keeling) Islands"                      = "CC"
        "Colombia"                                     = "CO"
        "Comoros"                                      = "KM"
        "Congo"                                        = "CG"
        "Congo, The Democratic Republic of the"        = "CD"
        "Cook Islands"                                 = "CK"
        "Costa Rica"                                   = "CR"
        "Cote D'Ivoire"                                = "CI"
        "Croatia"                                      = "HR"
        "Cuba"                                         = "CU"
        "Cyprus"                                       = "CY"
        "Czech Republic"                               = "CZ"
        "Denmark"                                      = "DK"
        "Djibouti"                                     = "DJ"
        "Dominica"                                     = "DM"
        "Dominican Republic"                           = "DO"
        "Ecuador"                                      = "EC"
        "Egypt"                                        = "EG"
        "El Salvador"                                  = "SV"
        "Equatorial Guinea"                            = "GQ"
        "Eritrea"                                      = "ER"
        "Estonia"                                      = "EE"
        "Ethiopia"                                     = "ET"
        "Falkland Islands (Malvinas)"                  = "FK"
        "Faroe Islands"                                = "FO"
        "Fiji"                                         = "FJ"
        "Finland"                                      = "FI"
        "France"                                       = "FR"
        "French Guiana"                                = "GF"
        "French Polynesia"                             = "PF"
        "French Southern Territories"                  = "TF"
        "Gabon"                                        = "GA"
        "Gambia"                                       = "GM"
        "Georgia"                                      = "GE"
        "Germany"                                      = "DE"
        "Ghana"                                        = "GH"
        "Gibraltar"                                    = "GI"
        "Greece"                                       = "GR"
        "Greenland"                                    = "GL"
        "Grenada"                                      = "GD"
        "Guadeloupe"                                   = "GP"
        "Guam"                                         = "GU"
        "Guatemala"                                    = "GT"
        "Guernsey"                                     = "GG"
        "Guinea"                                       = "GN"
        "Guinea-Bissau"                                = "GW"
        "Guyana"                                       = "GY"
        "Haiti"                                        = "HT"
        "Heard Island and Mcdonald Islands"            = "HM"
        "Holy See (Vatican City State)"                = "VA"
        "Honduras"                                     = "HN"
        "Hong Kong"                                    = "HK"
        "Hungary"                                      = "HU"
        "Iceland"                                      = "IS"
        "India"                                        = "IN"
        "Indonesia"                                    = "ID"
        "Iran, Islamic Republic Of"                    = "IR"
        "Iraq"                                         = "IQ"
        "Ireland"                                      = "IE"
        "Isle of Man"                                  = "IM"
        "Israel"                                       = "IL"
        "Italy"                                        = "IT"
        "Jamaica"                                      = "JM"
        "Japan"                                        = "JP"
        "Jersey"                                       = "JE"
        "Jordan"                                       = "JO"
        "Kazakhstan"                                   = "KZ"
        "Kenya"                                        = "KE"
        "Kiribati"                                     = "KI"
        "Korea, Democratic People's Republic of"       = "KP"
        "Korea, Republic of"                           = "KR"
        "Kuwait"                                       = "KW"
        "Kyrgyzstan"                                   = "KG"
        "Lao People's Democratic Republic"             = "LA"
        "Latvia"                                       = "LV"
        "Lebanon"                                      = "LB"
        "Lesotho"                                      = "LS"
        "Liberia"                                      = "LR"
        "Libyan Arab Jamahiriya"                       = "LY"
        "Liechtenstein"                                = "LI"
        "Lithuania"                                    = "LT"
        "Luxembourg"                                   = "LU"
        "Macao"                                        = "MO"
        "Macedonia, The Former Yugoslav Republic of"   = "MK"
        "Madagascar"                                   = "MG"
        "Malawi"                                       = "MW"
        "Malaysia"                                     = "MY"
        "Maldives"                                     = "MV"
        "Mali"                                         = "ML"
        "Malta"                                        = "MT"
        "Marshall Islands"                             = "MH"
        "Martinique"                                   = "MQ"
        "Mauritania"                                   = "MR"
        "Mauritius"                                    = "MU"
        "Mayotte"                                      = "YT"
        "Mexico"                                       = "MX"
        "Micronesia, Federated States of"              = "FM"
        "Moldova, Republic of"                         = "MD"
        "Monaco"                                       = "MC"
        "Mongolia"                                     = "MN"
        "Montserrat"                                   = "MS"
        "Morocco"                                      = "MA"
        "Mozambique"                                   = "MZ"
        "Myanmar"                                      = "MM"
        "Namibia"                                      = "NA"
        "Nauru"                                        = "NR"
        "Nepal"                                        = "NP"
        "Netherlands"                                  = "NL"
        "Netherlands Antilles"                         = "AN"
        "New Caledonia"                                = "NC"
        "New Zealand"                                  = "NZ"
        "Nicaragua"                                    = "NI"
        "Niger"                                        = "NE"
        "Nigeria"                                      = "NG"
        "Niue"                                         = "NU"
        "Norfolk Island"                               = "NF"
        "Northern Mariana Islands"                     = "MP"
        "Norway"                                       = "NO"
        "Oman"                                         = "OM"
        "Pakistan"                                     = "PK"
        "Palau"                                        = "PW"
        "Palestinian Territory, Occupied"              = "PS"
        "Panama"                                       = "PA"
        "Papua New Guinea"                             = "PG"
        "Paraguay"                                     = "PY"
        "Peru"                                         = "PE"
        "Philippines"                                  = "PH"
        "Pitcairn"                                     = "PN"
        "Poland"                                       = "PL"
        "Portugal"                                     = "PT"
        "Puerto Rico"                                  = "PR"
        "Qatar"                                        = "QA"
        "Reunion"                                      = "RE"
        "Romania"                                      = "RO"
        "Russian Federation"                           = "RU"
        "RWANDA"                                       = "RW"
        "Saint Helena"                                 = "SH"
        "Saint Kitts and Nevis"                        = "KN"
        "Saint Lucia"                                  = "LC"
        "Saint Pierre and Miquelon"                    = "PM"
        "Saint Vincent and the Grenadines"             = "VC"
        "Samoa"                                        = "WS"
        "San Marino"                                   = "SM"
        "Sao Tome and Principe"                        = "ST"
        "Saudi Arabia"                                 = "SA"
        "Senegal"                                      = "SN"
        "Serbia and Montenegro"                        = "CS"
        "Seychelles"                                   = "SC"
        "Sierra Leone"                                 = "SL"
        "Singapore"                                    = "SG"
        "Slovakia"                                     = "SK"
        "Slovenia"                                     = "SI"
        "Solomon Islands"                              = "SB"
        "Somalia"                                      = "SO"
        "South Africa"                                 = "ZA"
        "South Georgia and the South Sandwich Islands" = "GS"
        "Spain"                                        = "ES"
        "Sri Lanka"                                    = "LK"
        "Sudan"                                        = "SD"
        "Suriname"                                     = "SR"
        "Svalbard and Jan Mayen"                       = "SJ"
        "Swaziland"                                    = "SZ"
        "Sweden"                                       = "SE"
        "Switzerland"                                  = "CH"
        "Syrian Arab Republic"                         = "SY"
        "Taiwan, Province of China"                    = "TW"
        "Tajikistan"                                   = "TJ"
        "Tanzania, United Republic of"                 = "TZ"
        "Thailand"                                     = "TH"
        "Timor-Leste"                                  = "TL"
        "Togo"                                         = "TG"
        "Tokelau"                                      = "TK"
        "Tonga"                                        = "TO"
        "Trinidad and Tobago"                          = "TT"
        "Tunisia"                                      = "TN"
        "Turkey"                                       = "TR"
        "Turkmenistan"                                 = "TM"
        "Turks and Caicos Islands"                     = "TC"
        "Tuvalu"                                       = "TV"
        "Uganda"                                       = "UG"
        "Ukraine"                                      = "UA"
        "United Arab Emirates"                         = "AE"
        "United Kingdom"                               = "GB"
        "United States"                                = "US"
        "United States Minor Outlying Islands"         = "UM"
        "Uruguay"                                      = "UY"
        "Uzbekistan"                                   = "UZ"
        "Vanuatu"                                      = "VU"
        "Venezuela"                                    = "VE"
        "Viet Nam"                                     = "VN"
        "Virgin Islands, British"                      = "VG"
        "Virgin Islands, U.S."                         = "VI"
        "Wallis and Futuna"                            = "WF"
        "Western Sahara"                               = "EH"
        "Yemen"                                        = "YE"
        "Zambia"                                       = "ZM"
        "Zimbabwe"                                     = "ZW"
        "Hong Kong SAR"                                = "HK"
        "Serbia"                                       = "RS"
        "Korea"                                        = "KR"
        "Taiwan"                                       = "TW"
        "Vietnam"                                      = "VN"
    }

    $countryCode = $countryCode.Trim()
    if ($countryCodes.ContainsValue($countryCode.ToUpperInvariant())) {
        return $countryCode.ToLowerInvariant()
    }
    elseif ($countryCodes.ContainsKey($countryCode)) {
        return ($countryCodes[$countryCode]).ToLowerInvariant()
    }
    else {
        throw "Country code $countryCode is illegal"
    }
}

function Get-WWWRootPath {
    $inetstp = Get-Item "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue
    if ($inetstp) {
        [System.Environment]::ExpandEnvironmentVariables($inetstp.GetValue("PathWWWRoot"))
    }
    else {
        ""
    }
}

function Parse-JWTtoken([string]$token) {
    if ($token.Contains(".") -and $token.StartsWith("eyJ")) {
        $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
        while ($tokenPayload.Length % 4) { $tokenPayload += "=" }
        return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tokenPayload)) | ConvertFrom-Json
    }
    throw "Invalid token"
}

function Test-BcAuthContext {
    Param(
        $bcAuthContext
    )

    if (!(($bcAuthContext -is [Hashtable]) -and
          ($bcAuthContext.ContainsKey('ClientID')) -and
          ($bcAuthContext.ContainsKey('Credential')) -and
          ($bcAuthContext.ContainsKey('authority')) -and
          ($bcAuthContext.ContainsKey('RefreshToken')) -and
          ($bcAuthContext.ContainsKey('UtcExpiresOn')) -and
          ($bcAuthContext.ContainsKey('tenantID')) -and
          ($bcAuthContext.ContainsKey('AccessToken')) -and
          ($bcAuthContext.ContainsKey('includeDeviceLogin')) -and
          ($bcAuthContext.ContainsKey('deviceLoginTimeout')))) {
        throw 'BcAuthContext should be a HashTable created by New-BcAuthContext.'
    }
}

Function CreatePsTestToolFolder {
    Param(
        [string] $containerName,
        [string] $PsTestToolFolder
    )

    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"
    $newtonSoftDllPath = Join-Path $PsTestToolFolder "NewtonSoft.json.dll"
    $clientDllPath = Join-Path $PsTestToolFolder "Microsoft.Dynamics.Framework.UI.Client.dll"

    if (!(Test-Path -Path $PsTestToolFolder -PathType Container)) {
        New-Item -Path $PsTestToolFolder -ItemType Directory | Out-Null
        Copy-Item -Path (Join-Path $PSScriptRoot "AppHandling\PsTestFunctions.ps1") -Destination $PsTestFunctionsPath -Force
        Copy-Item -Path (Join-Path $PSScriptRoot "AppHandling\ClientContext.ps1") -Destination $ClientContextPath -Force
    }

    Invoke-ScriptInBcContainer -containerName $containerName { Param([string] $myNewtonSoftDllPath, [string] $myClientDllPath)
        if (!(Test-Path $myNewtonSoftDllPath)) {
            $newtonSoftDllPath = "C:\Program Files\Microsoft Dynamics NAV\*\Service\Management\NewtonSoft.json.dll"
            if (!(Test-Path $newtonSoftDllPath)) {
                $newtonSoftDllPath = "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll"
            }
            $newtonSoftDllPath = (Get-Item $newtonSoftDllPath).FullName
            Copy-Item -Path $newtonSoftDllPath -Destination $myNewtonSoftDllPath
        }
        if (!(Test-Path $myClientDllPath)) {
            $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
            Copy-Item -Path $clientDllPath -Destination $myClientDllPath
        }
    } -argumentList (Get-BcContainerPath -containerName $containerName -Path $newtonSoftDllPath), (Get-BcContainerPath -containerName $containerName -Path $clientDllPath)
}

function RandomChar([string]$str) {
    $rnd = Get-Random -Maximum $str.length
    [string]$str[$rnd]
}

function GetRandomPassword {
    $cons = 'bcdfghjklmnpqrstvwxz'
    $voc = 'aeiouy'
    $numbers = '0123456789'

    ((RandomChar $cons).ToUpper() + `
    (RandomChar $voc) + `
    (RandomChar $cons) + `
    (RandomChar $voc) + `
    (RandomChar $numbers) + `
    (RandomChar $numbers) + `
    (RandomChar $numbers) + `
    (RandomChar $numbers))
}

function getVolumeMountParameter($volumes, $hostPath, $containerPath) {
    $volume = $volumes | Where-Object { $_ -like "*|$hostPath" -or $_ -like "$hostPath|*" }
    if ($volume) {
        $volumeName = $volume.Split('|')[1]
        "--mount source=$($volumeName),target=$containerPath"
    }
    else {
        "--volume ""$($hostPath):$($containerPath)"""
    }
}

function testPfxCertificate([string] $pfxFile, [SecureString] $pfxPassword, [string] $certkind) {
    if (!(Test-Path $pfxFile)) {
        throw "$certkind certificate file does not exist"
    }
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfxFile, $pfxPassword)
    }
    catch {
        throw "Unable to read $certkind certificate. Error was $($_.Exception.Message)"
    }
    if ([DateTime]::Now -gt $cert.NotAfter) {
        throw "$certkind certificate expired on $($cert.GetExpirationDateString())"
    }
    if ([DateTime]::Now -gt $cert.NotAfter.AddDays(-14)) {
        Write-Host -ForegroundColor Yellow "$certkind certificate will expire on $($cert.GetExpirationDateString())"
    }
}

function GetHash {
    param(
        [string] $str
    )

    $stream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($str))
    (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
}

function Wait-Task {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Threading.Tasks.Task[]]$Task
    )

    Begin {
        $Tasks = @()
    }

    Process {
        $Tasks += $Task
    }

    End {
        While (-not [System.Threading.Tasks.Task]::WaitAll($Tasks, 200)) {}
        $Tasks.ForEach( { $_.GetAwaiter().GetResult() })
    }
}
Set-Alias -Name await -Value Wait-Task -Force

function DownloadFileLow {
    Param(
        [string] $sourceUrl,
        [string] $destinationFile,
        [switch] $dontOverwrite,
        [switch] $useDefaultCredentials,
        [switch] $skipCertificateCheck,
        [hashtable] $headers = @{"UserAgent" = "BcContainerHelper $bcContainerHelperVersion" },
        [int] $timeout = 100
    )

    if ($useTimeOutWebClient) {
        Write-Host "Downloading using WebClient"
        if ($skipCertificateCheck) {
            Write-Host "Disabling SSL Verification"
            [SslVerification]::Disable()
        }
        $webClient = New-Object TimeoutWebClient -ArgumentList (1000 * $timeout)
        $headers.Keys | ForEach-Object {
            $webClient.Headers.Add($_, $headers."$_")
        }
        $webClient.UseDefaultCredentials = $useDefaultCredentials
        if (Test-Path $destinationFile -PathType Leaf) {
            if ($dontOverwrite) { 
                return
            }
            Remove-Item -Path $destinationFile -Force
        }
        try {
            $webClient.DownloadFile($sourceUrl, $destinationFile)
        }
        finally {
            $webClient.Dispose()
            if ($skipCertificateCheck) {
                Write-Host "Restoring SSL Verification"
                [SslVerification]::Enable()
            }
        }
    }
    else {
        Write-Host "Downloading using HttpClient"
        
        $handler = New-Object System.Net.Http.HttpClientHandler
        if ($skipCertificateCheck) {
            Write-Host "Disabling SSL Verification on HttpClient"
            [SslVerification]::DisableSsl($handler)
        }
        if ($useDefaultCredentials) {
            $handler.UseDefaultCredentials = $true
        }
        $httpClient = New-Object System.Net.Http.HttpClient -ArgumentList $handler
        $httpClient.Timeout = [Timespan]::FromSeconds($timeout)
        $headers.Keys | ForEach-Object {
            $httpClient.DefaultRequestHeaders.Add($_, $headers."$_")
        }
        $stream = $null
        $fileStream = $null
        if ($dontOverwrite) {
            $fileMode = [System.IO.FileMode]::CreateNew
        }
        else {
            $fileMode = [System.IO.FileMode]::Create
        }
        try {
            $stream = $httpClient.GetStreamAsync($sourceUrl).GetAwaiter().GetResult()
            $fileStream = New-Object System.IO.Filestream($destinationFile, $fileMode)
            $stream.CopyToAsync($fileStream).GetAwaiter().GetResult() | Out-Null
            $fileStream.Close()
        }
        finally {
            if ($fileStream) {
                $fileStream.Dispose()
            }
            if ($stream) {
                $stream.Dispose()
            }
        }
    }
}

function LoadDLL {
    Param(
        [string] $path
    )
    $bytes = [System.IO.File]::ReadAllBytes($path)
    [System.Reflection.Assembly]::Load($bytes) | Out-Null
}

function GetAppInfo {
    Param(
        [string[]] $appFiles,
        [string] $compilerFolder,
        [string] $cacheAppInfoPath = ''
    )

    $appInfoCache = $null
    $cacheUpdated = $false
    if ($cacheAppInfoPath) {
        if (Test-Path $cacheAppInfoPath) {
            $appInfoCache = Get-Content -Path $cacheAppInfoPath -Encoding utf8 | ConvertFrom-Json
        }
        else {
            $appInfoCache = @{}
        }
    }
    Write-Host "::group::Getting .app info $cacheAppInfoPath"
    $binPath = Join-Path $compilerFolder 'compiler/extension/bin'
    if ($isLinux) {
        $alcPath = Join-Path $binPath 'linux'
        $alToolExe = Join-Path $alcPath 'altool'
        Write-Host "Setting execute permissions on altool"
        & /usr/bin/env sudo pwsh -command "& chmod +x $alToolExe"
    }
    elseif ($isMacOS) {
        $alcPath = Join-Path $binPath 'darwin'
        $alToolExe = Join-Path $alcPath 'altool'
        Write-Host "Setting execute permissions on altool"
        & chmod +x $alToolExe
    }
    else {
        $alcPath = Join-Path $binPath 'win32'
        $alToolExe = Join-Path $alcPath 'altool.exe'
    }
    if (-not (Test-Path $alcPath)) {
        $alcPath = $binPath
    }
    $alToolExists = Test-Path -Path $alToolExe -PathType Leaf
    $alcDllPath = $alcPath
    if (!($isLinux -or $isMacOS) -and !$isPsCore) {
        $alcDllPath = $binPath
    }

    $ErrorActionPreference = "STOP"
    $assembliesAdded = $false
    $packageStream = $null
    $package = $null
    try {
        foreach($path in $appFiles) {
            Write-Host -NoNewline "- $([System.IO.Path]::GetFileName($path))"
            if ($appInfoCache -and $appInfoCache.PSObject.Properties.Name -eq $path) {
                $appInfo = $appInfoCache."$path"
                Write-Host " (cached)"
            }
            else {
                if ($alToolExists) {
                    $manifest = CmdDo -Command $alToolExe -arguments @('GetPackageManifest', """$path""") -returnValue -silent | ConvertFrom-Json
                    $appInfo = @{
                        "appId"                 = $manifest.id
                        "publisher"             = $manifest.publisher
                        "name"                  = $manifest.name
                        "version"               = $manifest.version
                        "application"           = "$(if($manifest.PSObject.Properties.Name -eq 'application'){$manifest.application})"
                        "platform"              = "$(if($manifest.PSObject.Properties.Name -eq 'platform'){$manifest.Platform})"
                        "propagateDependencies" = ($manifest.PSObject.Properties.Name -eq 'PropagateDependencies') -and $manifest.PropagateDependencies
                        "dependencies"          = @(if($manifest.PSObject.Properties.Name -eq 'dependencies'){$manifest.dependencies | ForEach-Object { @{ "id" = $_.id; "name" = $_.name; "publisher" = $_.publisher; "version" = $_.version }}})
                    }
                }
                else {
                    if (!$assembliesAdded) {
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        Add-Type -AssemblyName System.Text.Encoding
                        LoadDLL -Path (Join-Path $alcDllPath Newtonsoft.Json.dll)
                        LoadDLL -Path (Join-Path $alcDllPath System.Collections.Immutable.dll)
                        if (Test-Path (Join-Path $alcDllPath System.IO.Packaging.dll)) {
        		            LoadDLL -Path (Join-Path $alcDllPath System.IO.Packaging.dll)
                        }
                        LoadDLL -Path (Join-Path $alcDllPath Microsoft.Dynamics.Nav.CodeAnalysis.dll)
                        $assembliesAdded = $true
                    }
                    $packageStream = [System.IO.File]::OpenRead($path)
                    $package = [Microsoft.Dynamics.Nav.CodeAnalysis.Packaging.NavAppPackageReader]::Create($PackageStream, $true)
                    $manifest = $package.ReadNavAppManifest()
                    $appInfo = @{
                        "appId"                 = $manifest.AppId
                        "publisher"             = $manifest.AppPublisher
                        "name"                  = $manifest.AppName
                        "version"               = "$($manifest.AppVersion)"
                        "dependencies"          = @($manifest.Dependencies | ForEach-Object { @{ "id" = $_.AppId; "name" = $_.Name; "publisher" = $_.Publisher; "version" = "$($_.Version)" } })
                        "application"           = "$($manifest.Application)"
                        "platform"              = "$($manifest.Platform)"
                        "propagateDependencies" = $manifest.PropagateDependencies
                    }
                }
                Write-Host " (succeeded)"
                if ($cacheAppInfoPath) {
                    $appInfoCache | Add-Member -MemberType NoteProperty -Name $path -Value $appInfo
                    $cacheUpdated = $true
                }
            }
            @{
                "Id"                    = $appInfo.appId
                "AppId"                 = $appInfo.appId
                "Publisher"             = $appInfo.publisher
                "Name"                  = $appInfo.name
                "Version"               = [System.Version]$appInfo.version
                "Dependencies"          = @($appInfo.dependencies)
                "Path"                  = $path
                "Application"           = $appInfo.application
                "Platform"              = $appInfo.platform
                "PropagateDependencies" = $appInfo.propagateDependencies
            }
        }
        if ($cacheUpdated) {
            $appInfoCache | ConvertTo-Json -Depth 99 | Set-Content -Path $cacheAppInfoPath -Encoding UTF8 -Force
        }
    }
    catch [System.Reflection.ReflectionTypeLoadException] {
        Write-Host " (failed)"
        if ($_.Exception.LoaderExceptions) {
            $_.Exception.LoaderExceptions | Select-Object -Property Message | Select-Object -Unique | ForEach-Object {
                Write-Host "LoaderException: $($_.Message)"
            }
        }
        throw
    }
    finally {
        if ($package) {
            $package.Dispose()
        }
        if ($packageStream) {
            $packageStream.Dispose()
        }
    }
    Write-Host "::endgroup::"
}

function GetLatestAlLanguageExtensionVersionAndUrl {
    Param(
        [switch] $allowPrerelease
    )

    $listing = Invoke-WebRequest -Method POST -UseBasicParsing `
                      -Uri https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1 `
                      -Body '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":[],"flags":0x192}' `
                      -ContentType application/json | ConvertFrom-Json
    
    $result =  $listing.results | Select-Object -First 1 -ExpandProperty extensions `
                         | Select-Object -ExpandProperty versions `
                         | Where-Object { ($allowPrerelease.IsPresent -or !(($_.properties.Key -eq 'Microsoft.VisualStudio.Code.PreRelease') -and ($_.properties | where-object { $_.Key -eq 'Microsoft.VisualStudio.Code.PreRelease' }).value -eq "true")) } `
                         | Select-Object -First 1

    if ($result) {
        $vsixUrl = $result.files | Where-Object { $_.assetType -eq "Microsoft.VisualStudio.Services.VSIXPackage"} | Select-Object -ExpandProperty source
        if ($vsixUrl) {
            return $result.version, $vsixUrl
        }
    }
    throw "Unable to locate latest AL Language Extension from the VS Code Marketplace"
}

function DetermineVsixFile {
    Param(
        [string] $vsixFile
    )

    if ($vsixFile -eq 'default') {
        return ''
    }
    elseif ($vsixFile -eq 'latest' -or $vsixFile -eq 'preview') {
        $version, $url = GetLatestAlLanguageExtensionVersionAndUrl -allowPrerelease:($vsixFile -eq 'preview')
        return $url
    }
    else {
        return $vsixFile
    }
}

# Cached Path for latest and preview versions of AL Language Extension
$AlLanguageExtenssionPath = @('','')

function DownloadLatestAlLanguageExtension {
    Param(
        [switch] $allowPrerelease
    )

    $mutexName = "DownloadAlLanguageExtension"
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    try {
        try {
            if (!$mutex.WaitOne(1000)) {
                Write-Host "Waiting for other process downloading AL Language Extension"
                $mutex.WaitOne() | Out-Null
                Write-Host "Other process completed downloading"
            }
        }
        catch [System.Threading.AbandonedMutexException] {
           Write-Host "Other process terminated abnormally"
        }

        # Check if we already have the latest version downloaded and located in this session
        if ($script:AlLanguageExtenssionPath[$allowPrerelease.IsPresent]) {
            $path = $script:AlLanguageExtenssionPath[$allowPrerelease.IsPresent]
            if (Test-Path $path -PathType Container) {
                return $path
            }
            else {
                $script:AlLanguageExtenssionPath[$allowPrerelease.IsPresent] = ''
            }
        }

        $version, $url = GetLatestAlLanguageExtensionVersionAndUrl -allowPrerelease:$allowPrerelease
        $path = Join-Path $bcContainerHelperConfig.hostHelperFolder "alLanguageExtension/$version"
        if (!(Test-Path $path -PathType Container)) {
            $AlLanguageExtensionsFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "alLanguageExtension"
            if (!(Test-Path $AlLanguageExtensionsFolder -PathType Container)) {
                New-Item -Path $AlLanguageExtensionsFolder -ItemType Directory | Out-Null
            }
            $description = "AL Language Extension"
            if ($allowPrerelease) {
                $description += " (Prerelease)"
            }
            $zipFile = "$path.zip"
            Download-File -sourceUrl $url -destinationFile $zipFile -Description $description
            Expand-7zipArchive -Path $zipFile -DestinationPath $path
            Remove-Item -Path $zipFile -Force
        }
        $script:AlLanguageExtenssionPath[$allowPrerelease.IsPresent] = $path
        return $path
    }
    finally {
        $mutex.ReleaseMutex()
    }
}

function RunAlTool {
    Param(
        [string[]] $arguments
    )
    # ALTOOL is at the moment only available in prerelease        
    $path = DownloadLatestAlLanguageExtension -allowPrerelease
    if ($isLinux) {
        $alToolExe = Join-Path $path 'extension/bin/linux/altool'
        Write-Host "Setting execute permissions on altool"
        & /usr/bin/env sudo pwsh -command "& chmod +x $alToolExe"
    } 
    elseif ($isMacOS) {
        $alToolExe = Join-Path $path 'extension/bin/darwin/altool'
        Write-Host "Setting execute permissions on altool"
        & chmod +x $alToolExe
    }
    else {
        $alToolExe = Join-Path $path 'extension/bin/win32/altool.exe'
    }
    CmdDo -Command $alToolExe -arguments $arguments -returnValue -silent
}

function GetApplicationDependency( [string] $appFile, [string] $minVersion = "0.0" ) {
    try {
        $appJson = Get-AppJsonFromAppFile -appFile $appFile
    }
    catch {
        Write-Host -ForegroundColor Red "Unable to read app $([System.IO.Path]::GetFileName($appFile)), ignoring application dependency check"
        return $minVersion
    }
    $version = $minVersion
    if ($appJson.PSObject.Properties.Name -eq "Application") {
        $version = $appJson.application
    }
    elseif ($appJson.PSObject.Properties.Name -eq "dependencies") {
        $baseAppDependency = $appJson.dependencies | Where-Object { $_.Name -eq "Base Application" -and $_.Publisher -eq "Microsoft" }
        if ($baseAppDependency) {
            $version = $baseAppDependency.Version
        }
    }
    if ([System.Version]$version -lt [System.Version]$minVersion) {
        $version = $minVersion
    }
    return $version
}
