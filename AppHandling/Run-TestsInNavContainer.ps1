<# 
 .Synopsis
  Run a test suite in a container
 .Description
 .Parameter containerName
  Name of the container in which you want to run a test suite
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter credential
  Credentials of the NAV SUPER user if using NavUserPassword authentication
 .Parameter testSuite
  Name of test suite to run. Default is DEFAULT.
 .Parameter XUnitResultFileName
  Credentials of the NAV SUPER user if using NavUserPassword authentication
 .Parameter AzureDevOps
  Generate Azure DevOps Pipeline compatible output. This setting determines the severity of errors.
 .Example
  Run-TestsInNavContainer -contatinerName test -credential $credential
 .Example
  Run-TestsInNavContainer -contatinerName $containername -credential $credential -XUnitResultFileName "c:\ProgramData\NavContainerHelper\$containername.results.xml" -AzureDevOps "warning"
#>
function Run-TestsInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$credential,
        [Parameter(Mandatory=$false)]
        [string] $testSuite = "DEFAULT",
        [Parameter(Mandatory=$false)]
        [string] $XUnitResultFileName,
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no',
        [switch] $detailed
    )
    
    $containerXUnitResultFileName = ""
    if ($XUnitResultFileName) {
        $containerXUnitResultFileName = Get-NavContainerPath -containerName $containerName -path $XUnitResultFileName
        if ("$containerXUnitResultFileName" -eq "") {
            throw "The path for XUnitResultFileName ($XUnitResultFileName) is not shared with the container."
        }
    }

    $TestRunnerFolder = "C:\ProgramData\NavContainerHelper\PsTestTool"
    If (!(Test-Path -Path $TestRunnerFolder -PathType Container)) { New-Item -Path $TestRunnerFolder -ItemType Directory | Out-Null }
    
    $PsTestRunnerPath = Join-Path $TestRunnerFolder "PsTestRunner.ps1"
    $ClientContextPath = Join-Path $TestRunnerFolder "ClientContext.ps1"
    $fobfile = Join-Path $TestRunnerFolder "PSTestTool.fob"
    
    if (!(Test-Path $PsTestRunnerPath)) {
        Download-File -sourceUrl "https://aka.ms/pstestrunnerps1" -destinationFile $PsTestRunnerPath
    }
    if (!(Test-Path $ClientContextPath)) {
        Download-File -sourceUrl "https://aka.ms/clientcontextps1" -destinationFile $ClientContextPath
    }
    if (!(Test-Path $fobfile)) {
        Download-File -sourceUrl "https://aka.ms/pstesttoolfob" -destinationFile $fobfile
    }
    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential
    
    Invoke-ScriptInNavContainer -containerName $containerName { Param([string] $tenant, [pscredential] $credential, [string] $testSuite, [string] $PsTestRunnerPath, [string] $XUnitResultFileName, [bool] $detailed)
    
        $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
        $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
        $idx = $publicWebBaseUrl.IndexOf('//')
        $protocol = $publicWebBaseUrl.Substring(0, $idx+2)
        $disableSslVerification = ($protocol -eq "https://")
        $serviceUrl = "${protocol}localhost/NAV/cs?tenant=$tenant"
    
        . $PsTestRunnerPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -TestSuite $testSuite -XUnitResultFileName $XUnitResultFileName -serviceUrl $serviceUrl -credential $credential -disableSslVerification:$disableSslVerification -detailed:$detailed
    
    } -argumentList $tenant, $credential, $testSuite, $PsTestRunnerPath, $containerXUnitResultFileName, $detailed
}
Export-ModuleMember -Function Run-TestsInNavContainer
