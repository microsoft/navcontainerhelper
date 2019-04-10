<# 
 .Synopsis
  Publish an AL Application (including Base App) to a Container
 .Description
  This function will replace the existing application (including base app) with a new application
  The application will be deployed using developer mode (same as used by VS Code)
 .Parameter containerName
  Name of the container to which you want to publish your AL Project
 .Parameter appFile
  Path of the appFile
 .Parameter appDotNetPackagesFolder
  Location of prokect specific dotnet reference assemblies. Default means that the app only uses standard DLLs.
  If your project is using custom DLLs, you will need to place them in this folder and the folder needs to be shared with the container.
 .Parameter credential
  Credentials of the container super user if using NavUserPassword authentication
 .Parameter useCleanDatabase
  Add this switch if you want to uninstall all extensioins and remove all C/AL objects in the range 1..1999999999.
  This switch is needed when turning a C/AL container into an AL Container.
 .Example
  Publish-NewApplicationToNavContainer -containerName test `
                                       -appFile (Join-Path $alProjectFolder ".output\$($appPublisher)_$($appName)_$($appVersion).app") `
                                       -appDotNetPackagesFolder (Join-Path $alProjectFolder ".netPackages") `
                                       -credential $credential

#>
function Publish-NewApplicationToNavContainer {
    Param(
        [string] $containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string] $appFile,
        [Parameter(Mandatory=$false)]
        [string] $appDotNetPackagesFolder,
        [Parameter(Mandatory=$false)]
        [pscredential] $credential,
        [switch] $useCleanDatabase
    )

    Add-Type -AssemblyName System.Net.Http

    $customconfig = Get-NavContainerServerConfiguration -ContainerName $containerName

    if ($customConfig.Multitenant -eq "True") {
        throw "This script doesn't support multitenancy yet"
    }

    $containerAppDotNetPackagesFolder = ""
    if ($appDotNetPackagesFolder -and (Test-Path $appDotNetPackagesFolder)) {
        $containerAppDotNetPackagesFolder = Get-NavContainerPath -containerName $containerName -path $appDotNetPackagesFolder -throw
    }
    
    Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param ( $appDotNetPackagesFolder )

        $serviceTierAddInsFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins").FullName
        $RTCAddInsFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client\Add-ins").FullName
    
        if (!(Test-Path (Join-Path $serviceTierAddInsFolder "RTCAddIns"))) {
            new-item -itemtype symboliclink -path $ServiceTierAddInsFolder -name "RTCAddIns" -value $RTCAddInsFolder | Out-Null
        }
        if (Test-Path (Join-Path $serviceTierAddInsFolder "ProjectDotNetPackages")) {
            (Get-Item (Join-Path $serviceTierAddInsFolder "ProjectDotNetPackages")).Delete()
        }
        if ($appDotNetPackagesFolder) {
            new-item -itemtype symboliclink -path $serviceTierAddInsFolder -name "ProjectDotNetPackages" -value $appDotNetPackagesFolder | Out-Null
        }

    } -argumentList $containerAppDotNetPackagesFolder

    if ($useCleanDatabase) {

        Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param ( $customConfig )
            
            if (!(Test-Path "c:\run\my\license.flf")) {
                throw "Container must be started with a developer license in order to publish a new application"
            }

            Write-Host "Uninstalling apps"
            Get-NAVAppInfo $customConfig.ServerInstance | Uninstall-NAVApp -DoNotSaveData -WarningAction Ignore -Force

            $tenant = "default"
        
            if ($customConfig.databaseInstance) {
                $databaseServerInstance = "$($customConfig.databaseServer)\$($customConfig.databaseInstance)"
            }
            else {
                $databaseServerInstance = $customConfig.databaseServer
            }

            Write-Host "Removing C/AL Application Objects"
            Delete-NAVApplicationObject -DatabaseName CRONUS -DatabaseServer $databaseServerInstance -Filter 'ID=1..1999999999' -SynchronizeSchemaChanges Force -Confirm:$false

        } -argumentList $customConfig
    }

    $handler = New-Object  System.Net.Http.HttpClientHandler
    if ($customConfig.ClientServicesCredentialType -eq "Windows") {
        $handler.UseDefaultCredentials = $true
    }
    $HttpClient = [System.Net.Http.HttpClient]::new($handler)
    if ($customConfig.ClientServicesCredentialType -eq "NavUserPassword") {
        $pair = ("$($Credential.UserName):"+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $HttpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $base64);
    }
    $HttpClient.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    $HttpClient.DefaultRequestHeaders.ExpectContinue = $false
    
    if ($customConfig.DeveloperServicesSSLEnabled -eq "true") {
        $protocol = "https://"
    }
    else {
        $protocol = "http://"
    }

    $ip = Get-NavContainerIpAddress -containerName $containerName
    if ($ip) {
        $devServerUrl = "$($protocol)$($ip):$($customConfig.DeveloperServicesPort)/$($customConfig.ServerInstance)"
    }
    else {
        $devServerUrl = "$($protocol)$($containerName):$($customConfig.DeveloperServicesPort)/$($customConfig.ServerInstance)"
    }

    $sslVerificationDisabled = ($protocol -eq "https://")
    if ($sslVerificationDisabled) {
        if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type)
        {
            Add-Type -TypeDefinition "
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public static class SslVerification
                {
                    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
                    public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
                    public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
                }"
        }
        Write-Host "Disabling SSL Verification"
        [SslVerification]::Disable()
    }

    $url = "$devServerUrl/dev/apps?SchemaUpdateMode=synchronize"
    
    $appName = [System.IO.Path]::GetFileName($appFile)
    
    $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
    $FileStream = [System.IO.FileStream]::new($appFile, [System.IO.FileMode]::Open)
    try {
        $fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
        $fileHeader.Name = "$AppName"
        $fileHeader.FileName = "$appName"
        $fileHeader.FileNameStar = "$appName"
        $fileContent = [System.Net.Http.StreamContent]::new($FileStream)
        $fileContent.Headers.ContentDisposition = $fileHeader
        $multipartContent.Add($fileContent)
        Write-Host "Publishing $appName to $url"
        $result = $HttpClient.PostAsync($url, $multipartContent).GetAwaiter().GetResult()
        if (!$result.IsSuccessStatusCode) {
            throw "Status Code $($result.StatusCode) : $($result.ReasonPhrase)"
        }
        Write-Host -ForegroundColor Green "New Application successfully published to $containerName"
    }
    finally {
        $FileStream.Close()
    }

    if ($sslverificationdisabled) {
        Write-Host "Re-enablssing SSL Verification"
        [SslVerification]::Enable()
    }
}
Export-ModuleMember Publish-NewApplicationToNavContainer
