# create script for running docker

$ErrorActionPreference = "stop"

function Select-Value {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $title,
        [Parameter(Mandatory=$false)]
        [string] $description,
        [Parameter(Mandatory=$true)]
        $options,
        [Parameter(Mandatory=$false)]
        [string] $default = "",
        [Parameter(Mandatory=$true)]
        [string] $question,
        [switch] $doNotClearHost = ($host.name -ne "ConsoleHost"),
        [switch] $writeAnswer = ($host.name -ne "ConsoleHost")
    )

    if (!$doNotClearHost) {
        Clear-Host
    }
    if ($title) {
        Write-Host -ForegroundColor Yellow $title
        Write-Host
    }
    if ($description) {
        Write-Host $description
        Write-Host
    }
    $offset = 0
    $defaultChr = -1
    $keys = @()
    $values = @()
    $options.GetEnumerator() | ForEach-Object {
        Write-Host -ForegroundColor Yellow "$([char]($offset+97)) " -NoNewline
        $keys += @($_.Key)
        $values += @($_.Value)
        if ($_.Key -eq $default) {
            Write-Host -ForegroundColor Yellow $_.Value
            $defaultAnswer = $offset
        }
        else {
            Write-Host $_.Value
        }
        $offset++     
    }
    Write-Host
    $answer = -1
    do {
        Write-Host "$question " -NoNewline
        if ($defaultAnswer -ge 0) {
            Write-Host "(default $([char]($defaultAnswer + 97))) " -NoNewline
        }
        $selection = (Read-Host).ToLowerInvariant()
        if ($selection -eq "") {
            if ($defaultAnswer -ge 0) {
                $answer = $defaultAnswer
            }
            else {
                Write-Host -ForegroundColor Red "No default value exists. " -NoNewline
            }
        }
        else {
            if (($selection.Length -ne 1) -or (([int][char]($selection)) -lt 97 -or ([int][char]($selection)) -ge (97+$offset))) {
                Write-Host -ForegroundColor Red "Illegal answer. " -NoNewline
            }
            else {
                $answer = ([int][char]($selection))-97
            }
        }
        if ($answer -eq -1) {
            if ($offset -eq 2) {
                Write-Host -ForegroundColor Red "Please answer one letter, a or b"
            }
            else {
                Write-Host -ForegroundColor Red "Please answer one letter, from a to $([char]($offset+97-1))"
            }
        }
    } while ($answer -eq -1)

    if ($writeAnswer) {
        Write-Host
        Write-Host -ForegroundColor Green "$($values[$answer]) selected"
        Write-Host
    }
    $keys[$answer]
}

function Enter-Value {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $title,
        [Parameter(Mandatory=$false)]
        [string] $description,
        [Parameter(Mandatory=$false)]
        $options,
        [Parameter(Mandatory=$false)]
        [string] $default = "",
        [Parameter(Mandatory=$true)]
        [string] $question,
        [switch] $doNotClearHost = ($host.name -ne "ConsoleHost"),
        [switch] $writeAnswer = ($host.name -ne "ConsoleHost")
    )

    if (!$doNotClearHost) {
        Clear-Host
    }
    if ($title) {
        Write-Host -ForegroundColor Yellow $title
        Write-Host
    }
    if ($description) {
        Write-Host $description
        Write-Host
    }
    $answer = ""
    do {
        Write-Host "$question " -NoNewline
        if ($options) {
            Write-Host "($([string]::Join(', ', $options))) " -NoNewline
        }
        if ($default) {
            Write-Host "(default $default) " -NoNewline
        }
        $selection = (Read-Host).ToLowerInvariant()
        if ($selection -eq "") {
            if ($default) {
                $answer = $default
            }
            else {
                Write-Host -ForegroundColor Red "No default value exists. "
            }
        }
        else {
            if ($options) {
                $answer = $options | Where-Object { $_ -like "$selection*" }
                if (-not ($answer)) {
                    Write-Host -ForegroundColor Red "Illegal answer. Please answer one of the options."
                }
                elseif ($answer -is [Array]) {
                    Write-Host -ForegroundColor Red "Multiple options match the answer. Please answer one of the options that matched the previous selection."
                    $options = $answer
                    $answer = $null
                }
            }
            else {
                $answer = $selection
            }
        }
    } while (-not ($answer))

    if ($writeAnswer) {
        Write-Host
        Write-Host -ForegroundColor Green "$answer selected"
        Write-Host
    }
    $answer
}

Clear-Host
$ErrorActionPreference = "STOP"

$module = Get-Module -Name "NavContainerHelper" -ErrorAction SilentlyContinue
if (!($module)) {
    Write-Host -ForegroundColor Red "This script has a dependency on the PowerShell module NavContainerHelper."
    Write-Host -ForegroundColor Red "See more here: https://www.powershellgallery.com/packages/navcontainerhelper"
    Write-Host -ForegroundColor Red "Use 'Install-Module NavContainerHelper -force' to install in PowerShell"
    return
}
elseif ($module.Version -eq [Version]"0.0") {
    $function = $module.ExportedFunctions.GetEnumerator() | Where-Object { $_.Key -eq "Get-BcArtifactUrl" }
    if (!($function)) {
        Write-Host -ForegroundColor Red "Your version of the NavContainerHelper PowerShell module is not up-to-date."
        Write-Host -ForegroundColor Red "Please pull a new version of the sources or install the module using: Install-Module NavContainerHelper -force"
        return
    }
    Write-Host -ForegroundColor Green "Running a cloned version of NavContainerHelper, which seems to be OK"
    Write-Host
}
elseif ($module.Version -lt [Version]"0.7.0.9") {
     Write-Host -ForegroundColor Red "Your version of the NavContainerHelper PowerShell module is not up-to-date."
     Write-Host -ForegroundColor Red "Please update the module using: Update-Module NavContainerHelper -force"
     return
}
else {
    Write-Host -ForegroundColor Green "Running NavContainerHelper $($module.Version.ToString())"
    Write-Host
}

$acceptEula = Enter-Value `
    -title "Accept Eula" `
    -Description "The supplemental license terms for running Business Central and NAV on Docker can be found here: https://go.microsoft.com/fwlink/?linkid=861843" `
    -options @("Y","N") `
    -question "Please enter Y if you accept the eula"

if ($acceptEula -ne "Y") {
    Write-Host -ForegroundColor Red "Eula not accepted, aborting..."
    return
}

$licenserequired = $false

$hosting = Select-Value `
    -title "Local or Azure VM" `
    -description "Specify where you want to host your Business Central container?`n`nSelecting Local will create a script that needs to run on a computer, which have Docker installed.`nSelecting Azure VM shows a Url with which you can create a VM. This requires an Azure Subscription." `
    -options ([ordered]@{"Local" = "Local docker container"; "AzureVM" = "Docker container in an Azure VM"}) `
    -question "Hosting" `
    -default "Local"

if ($hosting -eq "Local") {
    $auth = Select-Value `
        -title "Authentication" `
        -description "Select desired authentication mechanism.`nSelecting predefined credentials means that the script will use hardcoded credentials.`n`nNote: When using Windows authentication, you need to use your Windows Credentials from the host computer and if the computer is domain joined, you will need to be connected to the domain while running the container. You cannot use containers with Windows authentication when offline." `
        -options ([ordered]@{"UserPassword" = "Username/Password authentication"; "Credential" = "Username/Password authentication (with predefined credentials)"; "Windows" = "Windows authentication"}) `
        -question "Authentication" `
        -default "Credential"

    $containerName = Enter-Value `
        -title "Container Name" `
        -description "Enter the name of the container.`nContainer names are case sensitive and must start with a letter.`n`nNote: We recommend short lower case names as container names." `
        -question "Container name" `
        -default "my"

}
else {
    $auth = "UserPassword"
    $containerName = "navserver"
}

$predef = Select-Value `
    -title "Version" `
    -description "What version of Business Central do you need?`nIf you are developing a Per Tenant Extension for a Business Central Saas tenant, you need a Business Central Sandbox environment" `
    -options ([ordered]@{"LatestSandbox" = "Latest Business Central Sandbox"; "LatestOnPrem" = "Latest Business Central OnPrem"; "SpecificSandbox" = "Specific Business Central Sandbox build (requires version number)"; "SpecificOnPrem" = "Specific Business Central OnPrem build (requires version number)"}) `
    -question "Version" `
    -default "LatestSandbox" `
    -writeAnswer

if ($type -eq "Sandbox") {
    $default = "us"
    $description = "Please select which country version you want to use.`n`nNote: base is the onprem w1 demodata running in sandbox mode."
}
else {
    $default = "w1"
    $description = "Please select which country version you want to use.`n`nNote: NA contains US, CA and MX."
}

$select = "Latest"
if ($predef -like "Latest*") {
    $type = $predef.Substring(6)
    $version = (Get-BcArtifactUrl -type $type -country "w1").split('/')[4]

    $countries = @()
    Get-BCArtifactUrl -type $type -version $version -select All | ForEach-Object {
        $countries += $_.SubString($_.LastIndexOf('/')+1)
    }

    $country = Enter-Value `
        -description $description `
        -options $countries `
        -default $default `
        -question "Country" `
        -doNotClearHost
    $version = ""
}
elseif ($predef -like "specific*") {
    $type = $predef.Substring(8)
    $ok = $false
    do {
        $version = Enter-Value `
            -description "Specify version number.`nIf you specify a full version number (like 15.4.41023.41345), you will get the closest version.`nIf multiple versions matches the entered value, you will be asked to select" `
            -question "Enter version number (format major[.minor[.build[.release]]])" `
            -doNotClearHost -writeAnswer

        if ($version.indexOf('.') -eq -1) {
            $verno = 0
            $ok = [int32]::TryParse($version, [ref]$verno)
            if (!$ok) {
                Write-Host -ForegroundColor Red "Illegal version number"
            }
            $fullVersionNo = $false
        }
        else {
            $verno = [Version]"0.0.0.0"
            $ok = [Version]::TryParse($version, [ref]$verno)
            if (!$ok) {
                Write-Host -ForegroundColor Red "Illegal version number"
            }
            $fullVersionNo = $verno.Revision -ne -1
        }

        if ($ok) {
            if ($fullVersionNo) {
                $select = "Closest"
                $artifactUrl = Get-BCArtifactUrl -type $type -version $version -country 'w1' -select 'Closest'
                if ($artifactUrl) {
                    $foundVersion = $artifactUrl.split('/')[4]
                    if ($foundVersion -ne $version) {
                        Write-Host -ForegroundColor Yellow "The specific version doesn't exist, closest version is $foundVersion"
                    }
                    $countries = @()
                    Get-BCArtifactUrl -type $type -version $foundVersion -select All | ForEach-Object {
                        $countries += $_.SubString($_.LastIndexOf('/')+1)
                    }

                    $country = Enter-Value -description $description `
                        -options $countries `
                        -default $default `
                        -question "Country" `
                        -doNotClearHost `
                        -writeAnswer

                }
                else {
                    Write-Host -ForegroundColor Red "Unable to find a version close to the specified version"
                    $ok = $false
                }
            }
            else {
                $versions = @()
                Get-BCArtifactUrl -type $type -version $version -country 'w1' -select All | ForEach-Object {
                    $versions += $_.Split('/')[4]
                }
                if ($versions.Count -eq 0) {
                    Write-Host -ForegroundColor Red "Unable to find a version matching the specified version"
                    $ok = $false
                }
                elseif ($versions.Count -gt 1) {
                    $version = Enter-Value `
                        -options $versions `
                        -question "Select specific version" `
                        -doNotClearHost `
                        -writeAnswer
                }

                if ($ok) {
                    $countries = @()
                    Get-BCArtifactUrl -type $type -version $version -select All | ForEach-Object {
                        $countries += $_.SubString($_.LastIndexOf('/')+1)
                    }
                    $country = Enter-Value `
                        -description $description `
                        -options $countries `
                        -default $default `
                        -question "Country" `
                        -doNotClearHost `
                        -writeAnswer
                }
            }
        }

    } while (!$ok)
}

if ($hosting -eq "Local") {
    $testtoolkit = Select-Value `
        -title "Test Toolkit" `
        -description "Do you need the test toolkit to be installed?`nThe Test Toolkit is needed in order to develop and run tests in the container.`n`nNote: Test Libraries requires a license in order to be used" `
        -options ([ordered]@{"Full" = "Full Test Toolkit (Test Framework, Test Libraries and Microsoft tests)"; "Libraries" = "Test Framework and Test Libraries"; "Framework" = "Test Framework"; "No" = "No Test Toolkit needed"}) `
        -question "Test Toolkit" `
        -default "No"
    if ($testtoolkit -ne "No") { $licenserequired = $true }
}

$assignPremiumPlan = "N"
$createTestUsers = "N"

if ($type -eq "Sandbox") {

    $assignPremiumPlan = Enter-Value `
        -title "Assign Premium Plan" `
        -Description "When running sandbox, you can select to assign premium plan to the users." `
        -options @("Y","N") `
        -question "Please enter Y if you want to assign premium plan" `
        -default "N"

    $createTestUsers = Enter-Value `
        -title "Create Test Users" `
        -Description "When running sandbox, you can select to add test users with special entitlements.`nThe users created are: ExternalAccountant, Premium, Essential, InternalAdmin, TeamMember and DelegatedAdmin.`n`nNote: This requires a license file to be specified." `
        -options @("Y","N") `
        -question "Please enter Y if you want to create test users" `
        -default "N"

    if ($createTestUsers -eq "Y") {
        $licenserequired = $true
    }
}

if ($licenserequired) {
    $description = "Please specify a license file url.`nDue to other selections, you need to specify a license file."
    $default = ""
}
else {
    $description = "Please specify a license file url.`nIf you do not specify a license file, you will use the default Cronus Demo License."
    $default = "blank"
}
if ($hosting -eq "Local") {
    $description += "`n`nThis can be a local file or a secure direct download url (see https://freddysblog.com/2017/02/26/create-a-secure-url-to-a-file/)"
}
else {
    $description += "`n`nThis needs to be a secure direct download url (see https://freddysblog.com/2017/02/26/create-a-secure-url-to-a-file/)"
}
 
$licenseFile = Enter-Value `
    -title "License File" `
    -description $description `
    -question "License File" `
    -default $default

if ($licenseFile -eq "blank") {
    $licenseFile = ""
}

if ($hosting -eq "Local") {

    $options = [ordered]@{"standard" = "Use standard DNS settings (configured in Docker Daemon)"; "usegoogledns" = "Add Google publis dns (8.8.8.8) as DNS to the container" }
    $hostDNS = Get-DnsClientServerAddress | Select-Object –ExpandProperty ServerAddresses | Where-Object { "$_".indexOf(':') -eq -1 } | Select -first 1
    if ($hostDNS) {
        $options += @{ "usehostdns" = "Add your hosts primary DNS server ($hostDNS) as DNS to the container" }
    }
    $dns = Select-Value `
        -title "DNS" `
        -description "On some networks, standard DNS resolution does not work inside containers.`nWhen this is the case, you will see a warning during start saying:`n`nWARNING: DNS resolution not working from within the container.`n`nSome times, this can be fixed by choosing a different DNS server. Some times you have to reconfigure your antivirus protection program to allow this." `
        -options $options `
        -question "Use DNS" `
        -default "standard"


    
    # TODO: Check Generic and set isolation



    # TODO: Select Database

    
}


if ($hosting -eq "Local") {
    $parameters = @()
    $script = @()
    
    $script += "`$containerName = '$containerName'"
    if ($auth -eq "Credential") {
        $script += "`$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)"
        $auth = "UserPassword"
    }
    elseif ($auth -eq "UserPassword") {
        $script += "`$credential = Get-Credential -Message 'Using UserPassword authentication. Please enter credentials for the container.'"
    }
    else {
        $script += "`$credential = Get-Credential -Message 'Using Windows authentication. Please enter your Windows credentials for the host computer.'"
    }
    $parameters += "-credential `$credential"

    $script += "`$auth = '$auth'"
    $parameters += "-auth `$auth"

    $script += "`$artifactUrl = Get-BcArtifactUrl -type '$type' -version '$version' -country '$country' -select '$select'"
    $parameters += "-artifactUrl `$artifactUrl"

    if ($testtoolkit -ne "No") {
        $parameters += "-includeTestToolkit"
        if ($testtoolkit -eq "Framework") {
            $parameters += "-includeTestFrameworkOnly"
        }
        elseif ($testtoolkit -eq "Libraries") {
            $parameters += "-includeTestLibrariesOnly"
        }
    }

    if ($assignPremiumPlan -eq "Y") {
        $parameters += "-assignPremiumPlan"
    }

    if ($licenseFile) {
        $script += "`$licenseFile = '$licenseFile'"
        $parameters += "-licenseFile `$licenseFile"
    }

    if ($dns -eq "usegoogledns") {
        $parameters += "-dns '8.8.8.8'"
    }
    elseif ($dns -eq "usehostdns") {
        $parameters += "-dns '$hostDNS'"
    }

    $script += "New-BcContainer ``"
    $script += "    -accept_eula ``"
    $script += "    -containerName `$containerName ``"
    $parameters | ForEach-Object { $script += "    $_ ``" }
    $script += "    -updateHosts"

    if ($createTestUsers -eq "Y") {
        $script += "Setup-BcContainerTestUsers -containerName `$containerName -Password `$credential.Password -credential `$credential"
    }

    $filename = Enter-Value `
        -title "Save script" `
        -description ([string]::Join("`n", $script)) `
        -question "Filename (or blank to skip saving)" `
        -default "blank"

    if ($filename -ne "blank") {
        $script | Out-File $filename
    }

    $executeScript = Enter-Value `
        -options @("Y","N") `
        -question "Execute Script" `
        -doNotClearHost

    if ($executeScript -eq "Y") {
        Invoke-Expression -Command ([string]::Join("`n", $script))
    }

}
else {

    $emailforletsencrypt = Enter-Value `
        -title "Azure VM - Self Signed or Lets Encrypt Certificate" `
        -description "Your Azure VM can be secured by a Self-Signed Certificate, meaning that you need to install this certificate on any machine connecting to the VM.`nYou can also select to use LetsEncrypt by specifying an email address of the person accepting subscriber agreement for LetsEncrypt (https://letsencrypt.org/repository/).`n`nNote: The LetsEncrypt certificate needs to be renewed after 90 days." `
        -question "Contact EMail for LetsEncrypt (blank to use Self Signed)" `
        -default "blank"

    $artifactUrl = [Uri]::EscapeDataString("bcartifacts/$type/$version/$country/$select".ToLowerInvariant())

    $url = "http://aka.ms/getbc?accepteula=Yes&artifacturl=$artifactUrl$licenseFileParameter"
    if ($licenseFile) {
        $url += "&licenseFileUri=$([Uri]::EscapeDataString($licenseFile))"
    }
    if ($assignPremiumPlan -eq "Y") {
        $url += "&AssignPremiumPlan=Yes"
    }
    if ($createTestUsers -eq "Y") {
        $url += "&CreateTestUsers=Yes"
    }
    if ($emailforletsencrypt -ne "blank") {
        $url += "&contactemailforletsencrypt=$([Uri]::EscapeDataString($emailforletsencrypt))"
    }

    $launchUrl = Enter-Value `
        -title "URL" `
        -description $url `
        -options @("Y","N") `
        -question "Launch Url"

    if ($launchUrl -eq "Y") {
        Start-Process $Url
    }
}
