<# 
 .Synopsis
  Run a test suite in a NAV/BC Container
 .Description
 .Parameter containerName
  Name of the container in which you want to run a test suite
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter companyName
  company to use if container
 .Parameter credential
  Credentials of the SUPER user if using NavUserPassword authentication
 .Parameter testSuite
  Name of test suite to run. Default is DEFAULT.
 .Parameter testCodeunit
  Name or ID of test codeunit to run. Wildcards (? and *) are supported. Default is *.
 .Parameter testFunction
  Name of test function to run. Wildcards (? and *) are supported. Default is *.
 .Parameter XUnitResultFileName
  Filename where the function should place an XUnit compatible result file
 .Parameter AppendToXUnitResultFile
  Specify this switch if you want the function to append to the XUnit compatible result file instead of overwriting it
 .Parameter ReRun
  Specify this switch if you want the function to replace an existing test run (of the same test codeunit) in the XUnit compatible result file instead of adding it
 .Parameter AzureDevOps
  Generate Azure DevOps Pipeline compatible output. This setting determines the severity of errors.
 .Parameter InteractionTimeout
  Timespan allowed for a single interaction (Running a test codeunit is an interaction). Default is 24 hours.
 .Parameter ReturnTrueIfAllPassed
  Specify this switch if the function should return true/false on whether all tests passes. If not specified, the function returns nothing.
 .Example
  Run-TestsInNavContainer -contatinerName test -credential $credential
 .Example
  Run-TestsInNavContainer -contatinerName $containername -credential $credential -XUnitResultFileName "c:\ProgramData\NavContainerHelper\$containername.results.xml" -AzureDevOps "warning"
#>
function Run-TestsInNavContainer {
    Param(
        [string] $containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [string] $companyName = "",
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential = $null,
        [Parameter(Mandatory=$false)]
        [string] $testSuite = "DEFAULT",
        [Parameter(Mandatory=$false)]
        [string] $testGroup = "*",
        [Parameter(Mandatory=$false)]
        [string] $testCodeunit = "*",
        [Parameter(Mandatory=$false)]
        [string] $testFunction = "*",
        [Parameter(Mandatory=$false)]
        [string] $XUnitResultFileName,
        [switch] $AppendToXUnitResultFile,
        [switch] $ReRun,
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no',
        [switch] $detailed,
        [timespan] $interactionTimeout = [timespan]::FromHours(24),
        [switch] $returnTrueIfAllPassed
    )
    
    $containerXUnitResultFileName = ""
    if ($XUnitResultFileName) {
        $containerXUnitResultFileName = Get-NavContainerPath -containerName $containerName -path $XUnitResultFileName
        if ("$containerXUnitResultFileName" -eq "") {
            throw "The path for XUnitResultFileName ($XUnitResultFileName) is not shared with the container."
        }
    }

    $PsTestToolFolder = "C:\ProgramData\NavContainerHelper\Extensions\$containerName\PsTestTool-1"
    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"
    $fobfile = Join-Path $PsTestToolFolder "PSTestToolPage.fob"
    $clientServicesCredentialType = (Get-NavContainerServerConfiguration -ContainerName $containerName ).ClientServicesCredentialType

    If (!(Test-Path -Path $PsTestToolFolder -PathType Container)) {
        try {
            New-Item -Path $PsTestToolFolder -ItemType Directory | Out-Null
    
            Copy-Item -Path (Join-Path $PSScriptRoot "PsTestFunctions.ps1") -Destination $PsTestFunctionsPath -Force
            Copy-Item -Path (Join-Path $PSScriptRoot "ClientContext.ps1") -Destination $ClientContextPath -Force
            Copy-Item -Path (Join-Path $PSScriptRoot "PSTestToolPage.fob") -Destination $fobfile -Force

            if ($clientServicesCredentialType -eq "Windows") {
                Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile
            } else {
                Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential
            }
        } catch {
            Remove-Item -Path $PsTestToolFolder -Recurse -Force
            throw
        }
    }

    if ($clientServicesCredentialType -eq "Windows" -and "$CompanyName" -eq "") {
        $myName = $myUserName.SubString($myUserName.IndexOf('\')+1)
        Get-NavContainerNavUser -containerName $containerName | Where-Object { $_.UserName.EndsWith("\$MyName", [System.StringComparison]::InvariantCultureIgnoreCase) -or $_.UserName -eq $myName } | % {
            $companyName = $_.Company
        }
    }

    $allPassed = Invoke-ScriptInNavContainer -containerName $containerName { Param([string] $tenant, [string] $companyName, [pscredential] $credential, [string] $testSuite, [string] $testGroup, [string] $testCodeunit, [string] $testFunction, [string] $PsTestFunctionsPath, [string] $ClientContextPath, [string] $XUnitResultFileName, [bool] $AppendToXUnitResultFile, [bool] $ReRun, [string] $AzureDevOps, [bool] $detailed, [timespan] $interactionTimeout)
    
        $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
        $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
        $clientServicesCredentialType = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
        $idx = $publicWebBaseUrl.IndexOf('//')
        $protocol = $publicWebBaseUrl.Substring(0, $idx+2)
        $disableSslVerification = ($protocol -eq "https://")
        $serviceUrl = "$($protocol)localhost/$($ServerInstance)/cs?tenant=$tenant"

        if ($clientServicesCredentialType -eq "Windows") {
            $windowsUserName = whoami
            $NavServerUser = Get-NAVServerUser -ServerInstance $ServerInstance -tenant $tenant -ErrorAction Ignore | Where-Object { $_.UserName -eq $windowsusername }
            if (!($NavServerUser)) {
                Write-Host "Creating $windowsusername as user"
                New-NavServerUser -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername -PermissionSetId SUPER
            }
        }

        if ($companyName) {
            $serviceUrl += "&company=$([Uri]::EscapeDataString($companyName))"
        }

        . $PsTestFunctionsPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath

        try {
            if ($disableSslVerification) {
                Disable-SslVerification
            }
            
            $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential -interactionTimeout $interactionTimeout
    
            Run-Tests -clientContext $clientContext `
                      -TestSuite $testSuite `
                      -TestGroup $testGroup `
                      -TestCodeunit $testCodeunit `
                      -TestFunction $testFunction `
                      -XUnitResultFileName $XUnitResultFileName `
                      -AppendToXUnitResultFile:$AppendToXUnitResultFile `
                      -ReRun:$ReRun `
                      -AzureDevOps $AzureDevOps `
                      -detailed:$detailed
        }
        finally {
            if ($disableSslVerification) {
                Enable-SslVerification
            }
            Remove-ClientContext -clientContext $clientContext
        }

    } -argumentList $tenant, $companyName, $credential, $testSuite, $testGroup, $testCodeunit, $testFunction, $PsTestFunctionsPath, $ClientContextPath, $containerXUnitResultFileName, $AppendToXUnitResultFile, $ReRun, $AzureDevOps, $detailed, $interactionTimeout
    if ($returnTrueIfAllPassed) {
        $allPassed
    }
}
Set-Alias -Name Run-TestsInBCContainer -Value Run-TestsInNavContainer
Export-ModuleMember -Function Run-TestsInNavContainer -Alias Run-TestsInBCContainer
