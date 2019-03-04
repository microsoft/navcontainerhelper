<# 
 .Synopsis
  Get test information from a container
 .Description
 .Parameter containerName
  Name of the container from which you want to get test information
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter credential
  Credentials of the NAV SUPER user if using NavUserPassword authentication
 .Parameter testSuite
  Name of test suite to get. Default is DEFAULT.
 .Parameter testCodeunit
  Name or ID of test codeunit to get. Wildcards (? and *) are supported. Default is *.
 .Example
  Get-TestsFromNavContainer -contatinerName test -credential $credential
 .Example
  Get-TestsFromNavContainer -contatinerName $containername -credential $credential -TestSuite "MYTESTS" -TestCodeunit "134001"
#>
function Get-TestsFromNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$credential = $null,
        [Parameter(Mandatory=$false)]
        [string] $testSuite = "DEFAULT",
        [Parameter(Mandatory=$false)]
        [string] $testCodeunit = "*"
    )
    
    $PsTestToolFolder = "C:\ProgramData\NavContainerHelper\Extensions\$containerName\PsTestTool"
    $PsTestFunctionsPath = Join-Path $PsTestToolFolder "PsTestFunctions.ps1"
    $ClientContextPath = Join-Path $PsTestToolFolder "ClientContext.ps1"
    $fobfile = Join-Path $PsTestToolFolder "PSTestToolPage.fob"

    If (!(Test-Path -Path $PsTestToolFolder -PathType Container)) {
        try {
            New-Item -Path $PsTestToolFolder -ItemType Directory | Out-Null
    
            Download-File -sourceUrl "https://aka.ms/pstestfunctionsps1" -destinationFile $PsTestFunctionsPath
            Download-File -sourceUrl "https://aka.ms/clientcontextps1" -destinationFile $ClientContextPath
            Download-File -sourceUrl "https://aka.ms/pstesttoolpagefob" -destinationFile $fobfile

            if ((Get-NavContainerServerConfiguration -ContainerName $containerName ).ClientServicesCredentialType -eq "Windows") {
                Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile
            } else {
                Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential
            }
        } catch {
            Remove-Item -Path $PsTestToolFolder -Recurse -Force
            throw
        }
    }

    Invoke-ScriptInNavContainer -containerName $containerName { Param([string] $tenant, [pscredential] $credential, [string] $testSuite, [string] $testCodeunit, [string] $PsTestFunctionsPath, [string] $ClientContextPath)
    
        $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
        $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
        $ServerInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value
        $clientServicesCredentialType = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
        $idx = $publicWebBaseUrl.IndexOf('//')
        $protocol = $publicWebBaseUrl.Substring(0, $idx+2)
        $disableSslVerification = ($protocol -eq "https://")
        $serviceUrl = "${protocol}localhost/NAV/cs?tenant=$tenant"

        if ($clientServicesCredentialType -eq "Windows") {
            $windowsUserName = whoami
            if (!(Get-NAVServerUser -ServerInstance $ServerInstance -tenant $tenant -ErrorAction Ignore | Where-Object { $_.UserName -eq $windowsusername })) {
                Write-Host "Creating $windowsusername as user"
                New-NavServerUser -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -tenant $tenant -WindowsAccount $windowsusername -PermissionSetId SUPER
            }
        }

        . $PsTestFunctionsPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath        try {            if ($disableSslVerification) {                Disable-SslVerification            }                        $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $clientServicesCredentialType -credential $credential
            Get-Tests -clientContext $clientContext -TestSuite $testSuite -TestCodeunit $testCodeunit

        }
        finally {
            if ($disableSslVerification) {                Enable-SslVerification            }            Remove-ClientContext -clientContext $clientContext
        }

    } -argumentList $tenant, $credential, $testSuite, $testCodeunit, $PsTestFunctionsPath, $ClientContextPath | ConvertFrom-Json
}
Export-ModuleMember -Function Get-TestsFromNavContainer
