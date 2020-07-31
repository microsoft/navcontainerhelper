<# 
 .Synopsis
  Get test information from a NAV/BC Container
 .Description
 .Parameter containerName
  Name of the container from which you want to get test information
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter companyName
  company to use
 .Parameter profile
  profile to use
 .Parameter credential
  Credentials of the SUPER user if using NavUserPassword authentication
 .Parameter accesstoken
  If your container is running AAD authentication, you need to specify an accesstoken for the user specified in credential
 .Parameter testSuite
  Name of test suite to get. Default is DEFAULT.
 .Parameter testCodeunit
  Name or ID of test codeunit to get. Wildcards (? and *) are supported. Default is *.
 .Parameter testPage
  ID of the test page to use. Default for 15.x containers is 130455. Default for 14.x containers and earlier is 130409.
 .Parameter culture
  Set the culture when running the tests. Default is en-US. Microsoft tests are written for en-US.
 .Parameter timezone
  Set the timezone when running the tests. Default is current timezone.
 .Parameter debugMode
  Include this switch to output debug information if getting the tests fails.
 .Parameter ignoreGroups
  Test Groups are not supported in 15.x - include this switch to ignore test groups in 14.x and earlier and have compatible resultsets from this function
 .Parameter usePublicWebBaseUrl
  Connect to the public Url and not to localhost
 .Example
  Get-TestsFromBcContainer -contatinerName test -credential $credential
 .Example
  Get-TestsFromBcContainer -contatinerName $containername -credential $credential -TestSuite "MYTESTS" -TestCodeunit "134001"
#>
function Get-TestsFromBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [string] $companyName = "",
        [Parameter(Mandatory=$false)]
        [string] $profile = "",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [Parameter(Mandatory=$false)]
        [string] $accessToken = "",
        [Parameter(Mandatory=$false)]
        [string] $testSuite = "DEFAULT",
        [Parameter(Mandatory=$false)]
        [string] $testCodeunit = "*",
        [string] $extensionId = "",
        [array]  $disabledTests = @(),
        [Parameter(Mandatory=$false)]
        [int] $testPage,
        [string] $culture = "en-US",
        [string] $timezone = "",
        [switch] $debugMode,
        [switch] $ignoreGroups,
        [switch] $usePublicWebBaseUrl,
        [string] $useUrl
    )
    
    $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
    $version = [System.Version]($navversion.split('-')[0])

    if (!($PSBoundParameters.ContainsKey('usePublicWebBaseUrl'))) {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        if ($inspect.Config.Labels.psobject.Properties.Match('traefik.enable').Count -gt 0) {
            if ($inspect.config.Labels.'traefik.enable' -eq "true") {
                $usePublicWebBaseUrl = ($useUrl -eq "")
            }
        }
    }

    $PsTestToolFolder = Join-Path $extensionsFolder "$containerName\PsTestTool-6"
    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"
    $fobfile = Join-Path $PsTestToolFolder "PSTestToolPage.fob"
    $serverConfiguration = Get-BcContainerServerConfiguration -ContainerName $containerName
    $clientServicesCredentialType = $serverConfiguration.ClientServicesCredentialType

    if ($usePublicWebBaseUrl -and $useUrl -ne "") {
        throw "You cannot specify usePublicWebBaseUrl and useUrl at the same time"
    }

    if ($serverConfiguration.PublicWebBaseUrl -eq "") {
        throw "Container $containerName needs to include the WebClient in order to get tests (PublicWebBaseUrl is blank)"
    }

    if (!$testPage) {
        if ($version.Major -ge 15) {
            $testPage = 130455
        }
        else {
            $testPage = 130409
        }
    }

    If (!(Test-Path -Path $PsTestToolFolder -PathType Container)) {
        try {
            New-Item -Path $PsTestToolFolder -ItemType Directory | Out-Null
    
            Copy-Item -Path (Join-Path $PSScriptRoot "PsTestFunctions.ps1") -Destination $PsTestFunctionsPath -Force
            Copy-Item -Path (Join-Path $PSScriptRoot "ClientContext.ps1") -Destination $ClientContextPath -Force
        
            if ($version.Major -ge 15) {
                if ($testPage -eq 130409) {
                    Publish-BcContainerApp -containerName $containerName -appFile (Join-Path $PSScriptRoot "Microsoft_PSTestToolPage_15.0.0.0.app") -skipVerification -sync -install
                }
            }
            else {
                if ($version.Major -lt 11) {
                    Copy-Item -Path (Join-Path $PSScriptRoot "PSTestToolPage$($version.Major).fob") -Destination $fobfile -Force
                }
                else {
                    Copy-Item -Path (Join-Path $PSScriptRoot "PSTestToolPage.fob") -Destination $fobfile -Force
                }

                if ($clientServicesCredentialType -eq "Windows") {
                    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile
                } else {
                    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential
                }
            }
        } catch {
            Remove-Item -Path $PsTestToolFolder -Recurse -Force
            throw
        }
    }

    if ($clientServicesCredentialType -eq "Windows" -and "$CompanyName" -eq "") {
        $myName = $myUserName.SubString($myUserName.IndexOf('\')+1)
        Get-BcContainerNavUser -containerName $containerName | Where-Object { $_.UserName.EndsWith("\$MyName", [System.StringComparison]::InvariantCultureIgnoreCase) -or $_.UserName -eq $myName } | % {
            $companyName = $_.Company
        }
    }

    Invoke-ScriptInBCContainer -containerName $containerName -scriptBlock { Param($timeoutStr)
        $webConfigFile = "C:\inetpub\wwwroot\$WebServerInstance\web.config"
        try {
            $webConfig = [xml](Get-Content $webConfigFile)
            $node = $webConfig.configuration.'system.webServer'.aspNetCore.Attributes.GetNamedItem('requestTimeout')
            if (!($node)) {
                $node = $webConfig.configuration.'system.webServer'.aspNetCore.Attributes.Append($webConfig.CreateAttribute('requestTimeout'))
            }
            if ($node.Value -ne $timeoutStr) {
                $node.Value = $timeoutStr
                $webConfig.Save($webConfigFile)
            }
        }
        catch {
            Write-Host "WARNING: could not set requestTimeout in web.config"
        }
    } -argumentList "01:00:00"

    $result = Invoke-ScriptInBcContainer -containerName $containerName { Param([string] $tenant, [string] $companyName, [string] $profile, [pscredential] $credential, [string] $accessToken, [string] $testSuite, [string] $testCodeunit, [string] $PsTestFunctionsPath, [string] $ClientContextPath, $testPage, $version, $culture, $timezone, $debugMode, $ignoreGroups, $usePublicWebBaseUrl, $useUrl, $extensionId, $disabledtests)
    
        $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
        $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value.TrimEnd('/')
        $clientServicesCredentialType = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
        
        if ($useUrl) {
            $disableSslVerification = $false
            $serviceUrl = "$($useUrl.TrimEnd('/'))/cs?tenant=$tenant"
        }
        elseif ($usePublicWebBaseUrl) {
            $disableSslVerification = $false
            $serviceUrl = "$publicWebBaseUrl/cs?tenant=$tenant"
        } 
        else {
            $uri = [Uri]::new($publicWebBaseUrl)
            $disableSslVerification = ($Uri.Scheme -eq "https")
            $serviceUrl = "$($Uri.Scheme)://localhost:$($Uri.Port)/$($Uri.PathAndQuery)/cs?tenant=$tenant"
        }

        if ($clientServicesCredentialType -eq "Windows") {
            $windowsUserName = whoami
            if (!(Get-NAVServerUser -ServerInstance $ServerInstance -tenant $tenant -ErrorAction Ignore | Where-Object { $_.UserName -eq $windowsusername })) {
                Write-Host "Creating $windowsusername as user"
                New-NavServerUser -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername -PermissionSetId SUPER
            }
        }
        elseif ($accessToken) {
            $clientServicesCredentialType = "AAD"
            $credential = New-Object pscredential $credential.UserName, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)
        }

        if ($companyName) {
            $serviceUrl += "&company=$([Uri]::EscapeDataString($companyName))"
        }

        if ($profile) {
            $serviceUrl += "&profile=$([Uri]::EscapeDataString($profile))"
        }

        . $PsTestFunctionsPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath

        $clientContext = $null
        try {
            if ($disableSslVerification) {
                Disable-SslVerification
            }
            
            $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -culture $culture -timezone $timezone -debugMode:$debugMode

            Get-Tests -clientContext $clientContext `
                      -TestSuite $testSuite `
                      -TestCodeunit $testCodeunit `
                      -ExtensionId $extensionId `
                      -DisabledTests $disabledtests `
                      -testPage $testPage `
                      -debugMode:$debugMode `
                      -ignoreGroups:$ignoreGroups

        }
        catch {
            if ($debugMode -and $clientContext) {
                Dump-ClientContext -clientcontext $clientContext 
            }
            throw
        }
        finally {
            if ($disableSslVerification) {
                Enable-SslVerification
            }
            if ($clientContext) {
                Remove-ClientContext -clientContext $clientContext
                $clientContext = $null
            }
        }

    } -argumentList $tenant, $companyName, $profile, $credential, $accessToken, $testSuite, $testCodeunit, (Get-BCContainerPath -containerName $containerName -path $PsTestFunctionsPath), (Get-BCContainerPath -containerName $containerName -path $ClientContextPath), $testPage, $version, $culture, $timezone, $debugMode, $ignoreGroups, $usePublicWebBaseUrl, $useUrl, $extensionId, $disabledtests

    # When Invoke-ScriptInContainer is running as non-administrator - Write-Host (like license warnings) are send to the output
    # If the output is an array - grab the last item.
    if ($result -is [array]) {
        0..($result.Count-2) | % { Write-Host $result[$_] }
        $result[$result.Count-1] | ConvertFrom-Json
    }
    else {
        $result | ConvertFrom-Json
    }
}
Set-Alias -Name Get-TestsFromNavContainer -Value Get-TestsFromBcContainer
Export-ModuleMember -Function Get-TestsFromBcContainer -Alias Get-TestsFromNavContainer
