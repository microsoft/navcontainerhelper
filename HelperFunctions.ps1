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
        [ValidateSet('run','start','pull','restart','stop', 'rmi')]
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
            elseif ([DateTime]::Now.AddDays(14) -gt [DateTime]$se) {
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
        [switch] $includeTestRunnerOnly,
        [switch] $includePerformanceToolkit
    )

    Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($includeTestLibrariesOnly, $includeTestFrameworkOnly, $includeTestRunnerOnly, $includePerformanceToolkit)
    
        # Add Test Framework
        $apps = @(get-childitem -Path "C:\Applications\TestFramework\TestRunner\*.*" -recurse -filter "*.app")

        if (!$includeTestRunnerOnly) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestLibraries\*.*" -recurse -filter "*.app")

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
        }

        if ($includePerformanceToolkit) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*Toolkit.app")
            if (!$includeTestFrameworkOnly) {
                $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*.app" -exclude "*Toolkit.app")
            }
        }

        $apps | % {
            $appFile = Get-ChildItem -path "c:\applications.*\*.*" -recurse -filter ($_.Name).Replace(".app","_*.app")
            if (!($appFile)) {
                $appFile = $_
            }
            $appFile
        }
    } -argumentList $includeTestLibrariesOnly, $includeTestFrameworkOnly, $includeTestRunnerOnly, $includePerformanceToolkit
}

function GetExtenedErrorMessage {
    Param(
        [System.Net.WebException] $webException
    )

    $message = $webException.Message
    try {
        $webResponse = $webException.Response
        $reqstream = $webResponse.GetResponseStream()
        $sr = new-object System.IO.StreamReader $reqstream
        $result = $sr.ReadToEnd()
        try {
            $json = $result | ConvertFrom-Json
            $message += " $($json.Message)"
        }
        catch {
            $message += " $result"
        }
        try {
            $message += " (ms-correlation-x = $($webResponse.GetResponseHeader('ms-correlation-x')))"
        }
        catch {}
    }
    catch{}
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
    $appFiles | Where-Object{ $_ } | % {
        $appFile = $_
        if ($appFile -like "http://*" -or $appFile -like "https://*") {
            $appUrl = $appFile
            $appFile = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
            Download-File -sourceUrl $appUrl -destinationFile $appFile
            CopyAppFilesToFolder -appFile $appFile -folder $folder
            Remove-Item -Path $appFile -Force
        }
        elseif (Test-Path $appFile -PathType Container) {
            get-childitem $appFile -Filter '*.app' -Recurse | % {
                $destFile = Join-Path $folder $_.Name
                Copy-Item -Path $_.FullName -Destination $destFile -Force
                $destFile
            }
        }
        elseif (Test-Path $appFile -PathType Leaf) {
            if ([string]::new([char[]](Get-Content $appFile -Encoding byte -TotalCount 2)) -eq "PK") {
                $tmpFolder = Join-Path (Get-TempDir) ([Guid]::NewGuid().ToString())
                $copied = $false
                try {
                    if ($appFile -notlike "*.zip") {
                        $orgAppFile = $appFile
                        $appFile = Join-Path (Get-TempDir) "$([System.IO.Path]::GetFileName($orgAppFile)).zip"
                        Copy-Item $orgAppFile $appFile
                        $copied = $true
                    }
                    Expand-Archive $appfile -DestinationPath $tmpFolder -Force
                    Get-ChildItem -Path $tmpFolder -Recurse | Where-Object { $_.Name -like "*.app" -or $_.Name -like "*.zip" } | % {
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
                Copy-Item -Path $appFile -Destination $destFile -Force
                $destFile
            }
        }
        else {
            Write-Host -ForegroundColor Red "File not found: $appFile"
        }
    }
}

function getCountryCode {
    Param(
        [string] $countryCode
    )

    $countryCodes = @{
        "Afghanistan" = "AF"
        "Åland Islands" = "AX"
        "Albania" = "AL"
        "Algeria" = "DZ"
        "American Samoa" = "AS"
        "AndorrA" = "AD"
        "Angola" = "AO"
        "Anguilla" = "AI"
        "Antarctica" = "AQ"
        "Antigua and Barbuda" = "AG"
        "Argentina" = "AR"
        "Armenia" = "AM"
        "Aruba" = "AW"
        "Australia" = "AU"
        "Austria" = "AT"
        "Azerbaijan" = "AZ"
        "Bahamas" = "BS"
        "Bahrain" = "BH"
        "Bangladesh" = "BD"
        "Barbados" = "BB"
        "Belarus" = "BY"
        "Belgium" = "BE"
        "Belize" = "BZ"
        "Benin" = "BJ"
        "Bermuda" = "BM"
        "Bhutan" = "BT"
        "Bolivia" = "BO"
        "Bosnia and Herzegovina" = "BA"
        "Botswana" = "BW"
        "Bouvet Island" = "BV"
        "Brazil" = "BR"
        "British Indian Ocean Territory" = "IO"
        "Brunei Darussalam" = "BN"
        "Bulgaria" = "BG"
        "Burkina Faso" = "BF"
        "Burundi" = "BI"
        "Cambodia" = "KH"
        "Cameroon" = "CM"
        "Canada" = "CA"
        "Cape Verde" = "CV"
        "Cayman Islands" = "KY"
        "Central African Republic" = "CF"
        "Chad" = "TD"
        "Chile" = "CL"
        "China" = "CN"
        "Christmas Island" = "CX"
        "Cocos (Keeling) Islands" = "CC"
        "Colombia" = "CO"
        "Comoros" = "KM"
        "Congo" = "CG"
        "Congo, The Democratic Republic of the" = "CD"
        "Cook Islands" = "CK"
        "Costa Rica" = "CR"
        "Cote D'Ivoire" = "CI"
        "Croatia" = "HR"
        "Cuba" = "CU"
        "Cyprus" = "CY"
        "Czech Republic" = "CZ"
        "Denmark" = "DK"
        "Djibouti" = "DJ"
        "Dominica" = "DM"
        "Dominican Republic" = "DO"
        "Ecuador" = "EC"
        "Egypt" = "EG"
        "El Salvador" = "SV"
        "Equatorial Guinea" = "GQ"
        "Eritrea" = "ER"
        "Estonia" = "EE"
        "Ethiopia" = "ET"
        "Falkland Islands (Malvinas)" = "FK"
        "Faroe Islands" = "FO"
        "Fiji" = "FJ"
        "Finland" = "FI"
        "France" = "FR"
        "French Guiana" = "GF"
        "French Polynesia" = "PF"
        "French Southern Territories" = "TF"
        "Gabon" = "GA"
        "Gambia" = "GM"
        "Georgia" = "GE"
        "Germany" = "DE"
        "Ghana" = "GH"
        "Gibraltar" = "GI"
        "Greece" = "GR"
        "Greenland" = "GL"
        "Grenada" = "GD"
        "Guadeloupe" = "GP"
        "Guam" = "GU"
        "Guatemala" = "GT"
        "Guernsey" = "GG"
        "Guinea" = "GN"
        "Guinea-Bissau" = "GW"
        "Guyana" = "GY"
        "Haiti" = "HT"
        "Heard Island and Mcdonald Islands" = "HM"
        "Holy See (Vatican City State)" = "VA"
        "Honduras" = "HN"
        "Hong Kong" = "HK"
        "Hungary" = "HU"
        "Iceland" = "IS"
        "India" = "IN"
        "Indonesia" = "ID"
        "Iran, Islamic Republic Of" = "IR"
        "Iraq" = "IQ"
        "Ireland" = "IE"
        "Isle of Man" = "IM"
        "Israel" = "IL"
        "Italy" = "IT"
        "Jamaica" = "JM"
        "Japan" = "JP"
        "Jersey" = "JE"
        "Jordan" = "JO"
        "Kazakhstan" = "KZ"
        "Kenya" = "KE"
        "Kiribati" = "KI"
        "Korea, Democratic People's Republic of" = "KP"
        "Korea, Republic of" = "KR"
        "Kuwait" = "KW"
        "Kyrgyzstan" = "KG"
        "Lao People's Democratic Republic" = "LA"
        "Latvia" = "LV"
        "Lebanon" = "LB"
        "Lesotho" = "LS"
        "Liberia" = "LR"
        "Libyan Arab Jamahiriya" = "LY"
        "Liechtenstein" = "LI"
        "Lithuania" = "LT"
        "Luxembourg" = "LU"
        "Macao" = "MO"
        "Macedonia, The Former Yugoslav Republic of" = "MK"
        "Madagascar" = "MG"
        "Malawi" = "MW"
        "Malaysia" = "MY"
        "Maldives" = "MV"
        "Mali" = "ML"
        "Malta" = "MT"
        "Marshall Islands" = "MH"
        "Martinique" = "MQ"
        "Mauritania" = "MR"
        "Mauritius" = "MU"
        "Mayotte" = "YT"
        "Mexico" = "MX"
        "Micronesia, Federated States of" = "FM"
        "Moldova, Republic of" = "MD"
        "Monaco" = "MC"
        "Mongolia" = "MN"
        "Montserrat" = "MS"
        "Morocco" = "MA"
        "Mozambique" = "MZ"
        "Myanmar" = "MM"
        "Namibia" = "NA"
        "Nauru" = "NR"
        "Nepal" = "NP"
        "Netherlands" = "NL"
        "Netherlands Antilles" = "AN"
        "New Caledonia" = "NC"
        "New Zealand" = "NZ"
        "Nicaragua" = "NI"
        "Niger" = "NE"
        "Nigeria" = "NG"
        "Niue" = "NU"
        "Norfolk Island" = "NF"
        "Northern Mariana Islands" = "MP"
        "Norway" = "NO"
        "Oman" = "OM"
        "Pakistan" = "PK"
        "Palau" = "PW"
        "Palestinian Territory, Occupied" = "PS"
        "Panama" = "PA"
        "Papua New Guinea" = "PG"
        "Paraguay" = "PY"
        "Peru" = "PE"
        "Philippines" = "PH"
        "Pitcairn" = "PN"
        "Poland" = "PL"
        "Portugal" = "PT"
        "Puerto Rico" = "PR"
        "Qatar" = "QA"
        "Reunion" = "RE"
        "Romania" = "RO"
        "Russian Federation" = "RU"
        "RWANDA" = "RW"
        "Saint Helena" = "SH"
        "Saint Kitts and Nevis" = "KN"
        "Saint Lucia" = "LC"
        "Saint Pierre and Miquelon" = "PM"
        "Saint Vincent and the Grenadines" = "VC"
        "Samoa" = "WS"
        "San Marino" = "SM"
        "Sao Tome and Principe" = "ST"
        "Saudi Arabia" = "SA"
        "Senegal" = "SN"
        "Serbia and Montenegro" = "CS"
        "Seychelles" = "SC"
        "Sierra Leone" = "SL"
        "Singapore" = "SG"
        "Slovakia" = "SK"
        "Slovenia" = "SI"
        "Solomon Islands" = "SB"
        "Somalia" = "SO"
        "South Africa" = "ZA"
        "South Georgia and the South Sandwich Islands" = "GS"
        "Spain" = "ES"
        "Sri Lanka" = "LK"
        "Sudan" = "SD"
        "Suriname" = "SR"
        "Svalbard and Jan Mayen" = "SJ"
        "Swaziland" = "SZ"
        "Sweden" = "SE"
        "Switzerland" = "CH"
        "Syrian Arab Republic" = "SY"
        "Taiwan, Province of China" = "TW"
        "Tajikistan" = "TJ"
        "Tanzania, United Republic of" = "TZ"
        "Thailand" = "TH"
        "Timor-Leste" = "TL"
        "Togo" = "TG"
        "Tokelau" = "TK"
        "Tonga" = "TO"
        "Trinidad and Tobago" = "TT"
        "Tunisia" = "TN"
        "Turkey" = "TR"
        "Turkmenistan" = "TM"
        "Turks and Caicos Islands" = "TC"
        "Tuvalu" = "TV"
        "Uganda" = "UG"
        "Ukraine" = "UA"
        "United Arab Emirates" = "AE"
        "United Kingdom" = "GB"
        "United States" = "US"
        "United States Minor Outlying Islands" = "UM"
        "Uruguay" = "UY"
        "Uzbekistan" = "UZ"
        "Vanuatu" = "VU"
        "Venezuela" = "VE"
        "Viet Nam" = "VN"
        "Virgin Islands, British" = "VG"
        "Virgin Islands, U.S." = "VI"
        "Wallis and Futuna" = "WF"
        "Western Sahara" = "EH"
        "Yemen" = "YE"
        "Zambia" = "ZM"
        "Zimbabwe" = "ZW"
        "Hong Kong SAR" = "HK"
        "Serbia" = "RS"
        "Korea" = "KR"
        "Taiwan" = "TW"
        "Vietnam" = "VN"
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

function Get-TempDir {
    (Get-Item -Path $env:temp).FullName
}

function Parse-JWTtoken([string]$token) {
    if ($token.Contains(".") -and $token.StartsWith("eyJ")) {
        $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
        while ($tokenPayload.Length % 4) { $tokenPayload += "=" }
        return [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($tokenPayload)) | ConvertFrom-Json
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
          ($bcAuthContext.ContainsKey('Resource')) -and
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
            $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
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
    $volume = $volumes | Where-Object { $_ -like "$hostPath|*" }
    if ($volume) {
        $volumeName = $volume.Split('|')[1]
        "--mount source=$($volumeName),target=$containerPath"
    }
    else {
        "--volume ""$($hostPath):$($containerPath)"""
    }
}
