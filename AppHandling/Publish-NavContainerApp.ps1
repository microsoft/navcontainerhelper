<# 
 .Synopsis
  Publish App to a NAV/BC Container
 .Description
  Copies the appFile to the container if necessary
  Creates a session to the container and runs the CmdLet Publish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to publish an app (default is navserver)
 .Parameter appFile
  Path of the app you want to publish  
 .Parameter skipVerification
  Include this parameter if the app you want to publish is not signed
 .Parameter sync
  Include this parameter if you want to synchronize the app after publishing
  .Parameter syncMode
   Specify Add, Clean or Development based on how you want to synchronize the database schema. Default is Add
 .Parameter install
  Include this parameter if you want to install the app after publishing
 .Parameter tenant
  If you specify the install switch, then you can specify the tenant in which you want to install the app
 .Parameter packageType
  Specify Extension or SymbolsOnly based on which package you want to publish
 .Parameter scope
  Specify Global or Tenant based on how you want to publish the package. Default is Global
 .Parameter useDevEndpoint
  Specify the useDevEndpoint switch if you want to publish using the Dev Endpoint (like VS Code). This allows VS Code to re-publish.
 .Parameter credential
  Specify the credentials for the admin user if you use DevEndpoint and authentication is set to UserPassword
 .Parameter language
  Specify language version that is used for installing the app. The value must be a valid culture name for a language in Business Central, such as en-US or da-DK. If the specified language does not exist on the Business Central Server instance, then en-US is used.
 .Parameter replaceDependencies
  With this parameter, you can specify a hashtable, describring that the specified dependencies in the apps being published should be replaced
 .Example
  Publish-NavContainerApp -appFile c:\temp\myapp.app
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -install -sync
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification -install -sync -tenant mytenant
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -install -sync -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
function Publish-NavContainerApp {
    Param (
        [string] $containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string] $appFile,
        [switch] $skipVerification,
        [switch] $sync,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Add','Clean','Development','ForceSync')]
        [string] $syncMode,
        [switch] $install,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [ValidateSet('Extension','SymbolsOnly')]
        [string] $packageType = 'Extension',
        [Parameter(Mandatory=$false)]
        [ValidateSet('Global','Tenant')]
        [string] $scope,
        [switch] $useDevEndpoint,
        [pscredential] $credential,
        [string] $language = "",
        [hashtable] $replaceDependencies = $null
    )

    Add-Type -AssemblyName System.Net.Http
    $customconfig = Get-NavContainerServerConfiguration -ContainerName $containerName

    $copied = $false
    if ($appFile.ToLower().StartsWith("http://") -or $appFile.ToLower().StartsWith("https://")) {
        $appUrl = $appFile
        $appFile = Join-Path $extensionsFolder "$containerName\$([System.Uri]::UnescapeDataString([System.IO.Path]::GetFileName($appUrl).split("?")[0]))"
        (New-Object System.Net.WebClient).DownloadFile($appUrl, $appFile)
        $containerAppFile = Get-NavContainerPath -containerName $containerName -path $appFile
        $copied = $true
    }
    else {
        $containerAppFile = Get-NavContainerPath -containerName $containerName -path $appFile
        if ("$containerAppFile" -eq "") {
            $containerAppFile = Join-Path $extensionsFolder "$containerName\$([System.IO.Path]::GetFileName($appFile))"
            Copy-Item -Path $appFile -Destination $containerAppFile
            $copied = $true
        }
    }

    if ($useDevEndpoint) {

        if ($scope -eq "Global") {
            throw "You cannot publish to global scope using the dev. endpoint"
        }

        $handler = New-Object  System.Net.Http.HttpClientHandler
        if ($customConfig.ClientServicesCredentialType -eq "Windows") {
            $handler.UseDefaultCredentials = $true
        }
        $HttpClient = [System.Net.Http.HttpClient]::new($handler)
        if ($customConfig.ClientServicesCredentialType -eq "NavUserPassword") {
            if (!($credential)) {
                throw "You need to specify credentials when you are not using Windows Authentication"
            }
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
        
        $schemaUpdateMode = "synchronize"
        if ($syncMode -eq "Clean") {
            $schemaUpdateMode = "recreate";
        }
        elseif ($syncMode -eq "ForceSync") {
            $schemaUpdateMode = "forcesync"
        }
        $url = "$devServerUrl/dev/apps?SchemaUpdateMode=$schemaUpdateMode&tenant=$tenant"
        
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
    else {

        Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appFile, $skipVerification, $sync, $install, $tenant, $syncMode, $packageType, $scope, $language, $replaceDependencies)

            Function ReplaceDependenciesInApp {
                Param (
                    [string] $appFile,
                    $replaceDependencies
                )
            
                $zipArchive = $null
                $memoryStream = $null
                $fs = $null
                $binaryReader = $null
                $binaryWriter = $null
                $tempDir = (Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())) + "\"
                New-Item $tempDir -ItemType Directory | Out-Null

                try {

                    $fs = [System.IO.File]::OpenRead($appFile)
                    $binaryReader = [System.IO.BinaryReader]::new($fs)
                    $magicNumber1 = $binaryReader.ReadUInt32()
                    $metadataSize = $binaryReader.ReadUInt32()
                    $metadataVersion = $binaryReader.ReadUInt32()
                    $packageId = [Guid]::new($binaryReader.ReadBytes(16))
                    $contentLength = $binaryReader.ReadInt64()
                    $magicNumber2 = $binaryReader.ReadUInt32()
                    
                    if ($magicNumber1 -ne 0x5856414E -or 
                        $magicNumber2 -ne 0x5856414E -or 
                        $metadataVersion -gt 2 -or
                        $fs.Position + $contentLength -gt $fs.Length)
                    {
                        throw "Unsupported package format"
                    }
                
                    Add-Type -Assembly System.IO.Compression
                    Add-Type -Assembly System.IO.Compression.FileSystem
                    $content = $binaryReader.ReadBytes($contentLength)
                    $memoryStream = [System.IO.MemoryStream]::new($content)
                    $zipArchive = [System.IO.Compression.ZipArchive]::new($memoryStream, [System.IO.Compression.ZipArchiveMode]::Read)
                    $prevdir = ""
                    $zipArchive.Entries | ForEach-Object {
                        $fullname = Join-Path $tempDir $_.FullName
                        $dir = [System.IO.Path]::GetDirectoryName($fullname)
                        if ($dir -ne $prevdir) {
                            if (-not (Test-Path $dir -PathType Container)) {
                                New-Item -Path $dir -ItemType Directory | Out-Null
                            }
                        }
                        $prevdir = $dir
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $fullname)
                    }
                    $zipArchive.Dispose()
                    $zipArchive = $null
                    $binaryReader.Close()
                    $binaryReader = $null
                    $fs.Close()
                    $fs = $null

                    $changes = $false
                    $manifestFile = Join-Path $tempDir "NavxManifest.xml"
                    $manifest = [xml](Get-Content $manifestFile)
                    $manifest.Package.Dependencies.GetEnumerator() | % {
                        $dependency = $_
                        if ($replaceDependencies.ContainsKey($dependency.id)) {
                            $newDependency = $replaceDependencies[$dependency.id]
                            Write-Host "Replacing dependency from $($dependency.id) to $($newDependency.id)"
                            $dependency.id = $newDependency.id
                            $dependency.name = $newDependency.name
                            $dependency.publisher = $newDependency.publisher
                            $dependency.minVersion = $newDependency.minVersion
                            $changes = $true
                        }
                    }
                    if ($changes) {
            
                        $manifest.Save($manifestFile)
                        
                        $memoryStream = [System.IO.MemoryStream]::new()
                        $zipArchive = [System.IO.Compression.ZipArchive]::new($memoryStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
                        $files = [System.IO.Directory]::EnumerateFiles($tempDir, "*.*", [System.IO.SearchOption]::AllDirectories)
                        $files | % {
                            $file = $_.SubString($tempDir.Length)
                            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $_, $file) | Out-Null
                        }
                        $zipArchive.Dispose()
                        $zipArchive = $null
                        
                        $appFileName = [System.IO.Path]::GetTempFileName()
                        $fs = [System.IO.FileStream]::new($appFileName, [System.IO.FileMode]::Create)
                    
                        $binaryWriter = [System.IO.BinaryWriter]::new($fs)
                        $binaryWriter.Write([UInt32](0x5856414E))
                        $binaryWriter.Write([UInt32](40))
                        $binaryWriter.Write([UInt32](2))
                        $binaryWriter.Write($packageId.ToByteArray())
                        $binaryWriter.Write([UInt64]($memoryStream.Length))
                        $binaryWriter.Write([UInt32](0x5856414E))
                        
                        $memoryStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
                        $memoryStream.CopyTo($fs)
                        
                        return $appFileName
                    }
                    else {
                        return $appFile
                    }
                }
                catch {
                    return $appFile
                }
                finally {
                    if ($zipArchive) {
                        $zipArchive.Dispose()
                    }
                    if ($memoryStream) {
                        $memoryStream.Close()
                        $memoryStream.Dispose()
                    }
                    if ($binaryWriter) {
                        $binaryWriter.Close()
                    }
                    if ($binaryReader) {
                        $binaryReader.Close()
                    }
                    if ($fs) {
                        $fs.Close()
                    }
                    if (Test-Path $tempDir) {
                        Remove-Item -Path $tempDir -Recurse -Force
                    }
                }
            }
    
            $publishArgs = @{ "packageType" = $packageType }
            if ($scope) {
                $publishArgs += @{ "Scope" = $scope }
                if ($scope -eq "Tenant") {
                    $publishArgs += @{ "Tenant" = $tenant }
                }
            }
    
            $orgAppFile = $appFile
            if ($replaceDependencies) {
                Write-Host "Checking dependencies in $appFile"
                $appFile = ReplaceDependenciesInApp -appFile $appFile -replaceDependencies $replaceDependencies
            }

            Write-Host "Publishing $appFile"
            Publish-NavApp -ServerInstance $ServerInstance -Path $appFile -SkipVerification:$SkipVerification @publishArgs

            if ($sync -or $install) {

                $navAppInfo = Get-NAVAppInfo -Path $appFile
                $appPublisher = $navAppInfo.Publisher
                $appName = $navAppInfo.Name
                $appVersion = $navAppInfo.Version

                $syncArgs = @{}
                if ($syncMode) {
                    $syncArgs += @{ "Mode" = $syncMode }
                }
    
                if ($sync) {
                    Write-Host "Synchronizing $appName on tenant $tenant"
                    Sync-NavTenant -ServerInstance $ServerInstance -Tenant $tenant -Force
                    Sync-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant $tenant @syncArgs -force -WarningAction Ignore
                }
        
                if ($install) {

                    $languageArgs = @{}
                    if ($language) {
                        $languageArgs += @{ "Language" = $language }
                    }
                    Write-Host "Installing $appName on tenant $tenant"
                    Install-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant $tenant @languageArgs
                }
            }

            if ($appFile -ne $orgAppFile) {
                Remove-Item $appFile -Force -ErrorAction SilentlyContinue
            }

        } -ArgumentList $containerAppFile, $skipVerification, $sync, $install, $tenant, $syncMode, $packageType, $scope, $language, $replaceDependencies
    }

    if ($copied) { 
        Remove-Item $containerAppFile -Force
    }
    Write-Host -ForegroundColor Green "App successfully published"
}
Set-Alias -Name Publish-BCContainerApp -Value Publish-NavContainerApp
Export-ModuleMember -Function Publish-NavContainerApp -Alias Publish-BCContainerApp
