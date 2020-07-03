function Select-Value {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $title,
        [Parameter(Mandatory=$true)]
        [string] $description,
        [Parameter(Mandatory=$true)]
        $options,
        [string] $default,
        [Parameter(Mandatory=$true)]
        [string] $question
    )

    Clear-Host
    Clear-Host
    Write-Host -ForegroundColor Yellow $title
    Write-Host
    Write-Host $description
    Write-Host
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

    Write-Host
    Write-Host -ForegroundColor Green "$($values[$answer]) selected"
    Write-Host
    Write-Host
    $keys[$answer]
}

function Enter-Value {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $title,
        [Parameter(Mandatory=$true)]
        [string] $description,
        [Parameter(Mandatory=$false)]
        $options,
        [string] $default = "",
        [Parameter(Mandatory=$true)]
        [string] $question
    )

    Clear-Host
    Clear-Host
    Write-Host -ForegroundColor Yellow $title
    Write-Host
    Write-Host $description
    Write-Host
    if ($options) {
        Write-Host "$([string]::Join(', ', $options))"
        Write-Host
    }
    $answer = ""
    do {
        Write-Host "$question " -NoNewline
        if ($default) {
            Write-Host "(default $default) " -NoNewline
        }
        $selection = (Read-Host).ToLowerInvariant()
        if ($selection -eq "") {
            if ($default) {
                $answer = $default
            }
            else {
                Write-Host -ForegroundColor Red "No default value exists. " -NoNewline
            }
        }
        else {
            if ($options) {
                $answer = $options | Where-Object { $_ -eq $selection }
                if (-not ($answer)) {
                    Write-Host -ForegroundColor Red "Illegal answer. Please answer one of the options"
                }
            }
            else {
                $answer = $selection
            }
        }
    } while (-not ($answer))

    Write-Host
    Write-Host -ForegroundColor Green "$answer selected"
    Write-Host
    Write-Host
    $answer
}

cls

$acceptEula = Select-Value `
    -title "Accept Eula" `
    -Description "The supplemental license terms for running Business Central and NAV on Docker can be found here: https://go.microsoft.com/fwlink/?linkid=861843`n`nPlease select" `
    -options ([ordered]@{"Yes" = "Accept eula"; "No" = "Do not accept eula"}) `
    -question "Select a to accept eula or b if you don't"

if ($acceptEula -ne "Yes") {

    Write-Host -ForegroundColor Red "Eula not accepted, aborting..."

}
else {

$licenserequired = $false

$hosting = Select-Value `
    -title "Local or Azure VM" `
    -description "Specify where you want to host your Business Central container?`n`nSelecting Local will create a script that needs to run on a computer, which have Docker installed.`nSelecting Azure VM requires an Azure Subscription." `
    -options ([ordered]@{"Local" = "Local docker container"; "AzureVM" = "Docker container in an Azure VM"}) `
    -question "Hosting" `
    -default "Local"

if ($hosting -eq "Local") {
    $auth = Select-Value `
        -title "Authentication" `
        -description "Select desired authentication mechanism.`nSelecting predefined credentials means that you will the script will use hardcoded credentials.`n`nNote: When using Windows authentication, you need to use your Windows Credentials from the host computer and if the computer is domain joined, you will need to be connected to the domain. You cannot use Windows authentication when offline." `
        -options ([ordered]@{"UserPassword" = "Username/Password authentication"; "Credential" = "Username/Password authentication (with predefined credentials)"; "Windows" = "Windows authentication"}) `
        -question "Authentication" `
        -default "Credential"

    $containerName = Enter-Value `
        -title "Container Name" `
        -description "Enter the name of the container.`nContainer names are case sensitive and must start with a letter.`n`nNote: We recommend short lower case names as container names." `
        -question "Container name" `
        -default "my"

    $predef = Select-Value `
        -title "Version" `
        -description "Specify version" `
        -options ([ordered]@{"LatestSandbox" = "Latest Business Central Sandbox"; "LatestOnPrem" = "Latest Business Central OnPrem"; "SpecificSandbox" = "Specific Business Central Sandbox build (requires version number)"; "SpecificOnPrem" = "Specific Business Central OnPrem build (requires version number)"}) `
        -question "Version" `
        -default "LatestSandbox"

    if ($predef -like "Latest*") {
        $type = $predef.Substring(6)
        $version = (Get-BcArtifactUrl -type $type -country "w1").split('/')[4]

        $countries = @()
        Get-BCArtifactUrl -type $type -version $version -select All | ForEach-Object {
            $countries += $_.SubString($_.LastIndexOf('/')+1)
        }

        if ($type -eq "Sandbox") {
            $default = "us"
            $description = "Please select which localization you want to use.`n`nNote: base is the onprem w1 demodata running in sandbox mode."
        }
        else {
            $default = "w1"
            $description = "Please select which localization you want to use.`n`nNote: NA contains US, CA and MX."
        }

        $country = Enter-Value -title "Localization" -description $description -options $countries -default $default -question "Country"
        $select = "Latest"
        $version = ""
    }
    elseif ($predef -like "specific*") {
        $type = $predef.Substring(8)
        $version = Read-Host -Prompt "Version"

        #TODO
    }

    $testtoolkit = Select-Value `
        -title "Test Toolkit" `
        -description "Do you need the test toolkit to be installed?`nThe Test Toolkit is needed in order to develop and run tests in the container.`n`nNote: Test Libraries requires a license in order to be used" `
        -options ([ordered]@{"Full" = "Full Test Toolkit (Test Framework, Test Libraries and Microsoft tests)"; "Libraries" = "Test Framework and Test Libraries"; "Framework" = "Test Framework"; "No" = "No Test Toolkit needed"}) `
        -question "Test Toolkit" `
        -default "No"
    if ($testtoolkit -ne "No") { $licenserequired = $true }

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


}
else {
    $auth = "UserPassword"
}

$parameters = @()
$script = @()
if ($hosting -eq "Local") {
    $script += "Install-Module NavContainerHelper -Force"
    $script += ""
    $script += "`$containerName = '$containerName'"
    if ($auth -eq "Credential") {
        $script += "`$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)"
        $auth = "UserPassword"
        $parameters += "-credential `$credential"
    }
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

    if ($licenseFile) {
        $script += "`$licenseFile = '$licenseFile'"
        $parameters += "-licenseFile `$licenseFile"
    }

    $script += "New-BcContainer ``"
    $script += "    -accept_eula ``"
    $script += "    -containerName `$containerName ``"
    $parameters | ForEach-Object { $script += "    $_ ``" }
    $script += "    -updateHosts"

    $script | Out-Host

}
else {
    Write-Host "http://aka.ms/getbc"
}



}