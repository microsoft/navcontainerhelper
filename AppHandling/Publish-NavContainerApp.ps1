<# 
 .Synopsis
  Publish App to a NAV/BC Container
 .Description
  Copies the appFile to the container if necessary
  Creates a session to the container and runs the CmdLet Publish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to publish an app
 .Parameter appFile
  Path of the app you want to publish  
 .Parameter skipVerification
  Include this parameter if the app you want to publish is not signed
 .Parameter ignoreIfAppExists
  Include this parameter if you want to ignore the error if the app already is published/installed
 .Parameter sync
  Include this parameter if you want to synchronize the app after publishing
 .Parameter syncMode
  Specify Add, Clean or Development based on how you want to synchronize the database schema. Default is Add
 .Parameter install
  Include this parameter if you want to install the app after publishing
 .Parameter upgrade
  Include this parameter if you want to upgrade the app after publishing. if no upgrade is necessary then its just installed instead.
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
 .Parameter includeOnlyAppIds
  Array of AppIds. If specified, then include Only Apps in the specified AppFile array or archive which is contained in this Array and their dependencies
 .Parameter excludeRuntimePackages
  If specified, then runtime packages will be excluded
 .Parameter copyInstalledAppsToFolder
  If specified, the installed apps will be copied to this folder in addition to being installed in the container
 .Parameter replaceDependencies
  With this parameter, you can specify a hashtable, describring that the specified dependencies in the apps being published should be replaced
 .Parameter internalsVisibleTo
  An Array of hashtable, containing id, name and publisher of an app, which should be added to internals Visible to
 .Parameter showMyCode
  With this parameter you can change or check ShowMyCode in the app file. Check will throw an error if ShowMyCode is False.
 .Parameter PublisherAzureActiveDirectoryTenantId
  AAD Tenant of the publisher to ensure access to keyvault (unless publisher check is disables in server config)
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. By specifying BcAuthContext and environment, the function will publish the app to the online Business Central Environment specified
 .Parameter environment
  Environment to use for publishing
 .Example
  Publish-BcContainerApp -appFile c:\temp\myapp.app
 .Example
  Publish-BcContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification
 .Example
  Publish-BcContainerApp -containerName test2 -appFile c:\temp\myapp.app -install -sync
 .Example
  Publish-BcContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification -install -sync -tenant mytenant
 .Example
  Publish-BcContainerApp -containerName test2 -appFile c:\temp\myapp.app -install -sync -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
function Publish-BcContainerApp {
    Param (
        [string] $containerName = "",
        [Parameter(Mandatory=$true)]
        $appFile,
        [switch] $skipVerification,
        [switch] $ignoreIfAppExists,
        [switch] $sync,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Add','Clean','Development','ForceSync')]
        [string] $syncMode,
        [switch] $install,
        [switch] $upgrade,
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
        [string[]] $includeOnlyAppIds = @(),
        [string] $copyInstalledAppsToFolder = "",
        [hashtable] $replaceDependencies = $null,
        [hashtable[]] $internalsVisibleTo = $null,
        [ValidateSet('Ignore','True','False','Check')]
        [string] $ShowMyCode = "Ignore",
        [switch] $replacePackageId,
        [string] $PublisherAzureActiveDirectoryTenantId,
        [Hashtable] $bcAuthContext,
        [string] $environment,
        [switch] $checkAlreadyInstalled,
        [ValidateSet('default','ignore','strict')]
        [string] $dependencyPublishingOption = "default",
        [switch] $excludeRuntimePackages
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    Add-Type -AssemblyName System.Net.Http

    if ($containerName -eq "" -and (!($bcAuthContext -and $environment))) {
        $containerName = $bcContainerHelperConfig.defaultContainerName
    }
    $isCloudBcContainer = isCloudBcContainer -authContext $bcAuthContext -containerId $environment
    $installedApps = @()
    if ($containerName) {
        $customconfig = Get-BcContainerServerConfiguration -ContainerName $containerName
        $appFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder "Extensions\$containerName\$([guid]::NewGuid().ToString())"
        if ($appFile -is [string] -and $appFile.Startswith(':')) {
            New-Item $appFolder -ItemType Directory | Out-Null
            $destFile = Join-Path $appFolder ([System.IO.Path]::GetFileName($appFile.SubString(1)).Replace('*','').Replace('?',''))
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($appFile, $destFile)
                Copy-Item -Path $appFile -Destination $destFile -Force
            } -argumentList (Get-BcContainerPath -containerName $containerName -path $appFile), (Get-BcContainerPath -containerName $containerName -path $destFile) | Out-Null
            $appFiles = @($destFile)
        }
        else {
            $appFiles = CopyAppFilesToFolder -appFiles $appFile -folder $appFolder
        }
        $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
        $version = [System.Version]($navversion.split('-')[0])
        $force = ($version.Major -ge 14)
        if ($checkAlreadyInstalled) {
            # Get Installed apps (if UseDevEndpoint is specified, only get global apps)
            $installedApps = Get-BcContainerAppInfo -containerName $containerName -installedOnly | Where-Object { (-not $useDevEndpoint.IsPresent) -or ($_.Scope -eq 'Global') } | ForEach-Object {
                @{ "id" = $_.appId; "publisher" = $_.publisher; "name" = $_.name; "version" = $_.Version }
            }
        }
    }
    else {
        $appFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $appFiles = CopyAppFilesToFolder -appFiles $appFile -folder $appFolder
        $force = $true
        if ($checkAlreadyInstalled) {
            if ($isCloudBcContainer) {
                # Get Installed apps (if UseDevEndpoint is specified, only get global apps)
                $installedApps = Invoke-ScriptInCloudBcContainer -authContext $bcAuthContext -containerId $environment -scriptblock {
                    Get-NAVAppInfo -ServerInstance $serverInstance -TenantSpecificProperties -tenant 'default' | Where-Object { $_.IsInstalled -eq $true -and ((-not $useDevEndpoint.IsPresent) -or ($_.Scope -eq 'Global')) } | ForEach-Object { 
                        Get-NAVAppInfo -ServerInstance $serverInstance -TenantSpecificProperties -tenant 'default' -id $_.AppId -publisher $_.publisher -name $_.name -version $_.Version }
                }
            }
            else {
                # Get Installed apps (if UseDevEndpoint is specified, only get global apps or PTEs)
                # PublishedAs is either "Global", " PTE" or " Dev" (with leading space)
                $installedApps = Get-BcInstalledExtensions -bcAuthContext $bcAuthContext -environment $environment | Where-Object { $_.IsInstalled -and ((-not $useDevEndpoint.IsPresent) -or ($_.PublishedAs -ne ' Dev')) } | ForEach-Object {
                    @{ "id" = $_.id; "publisher" = $_.publisher; "name" = $_.displayName; "version" = [System.Version]::new($_.VersionMajor,$_.VersionMinor,$_.VersionBuild,$_.VersionRevision) }
                }
            }
        }
    }

    try {
        $appFiles = @(Sort-AppFilesByDependencies -containerName $containerName -appFiles $appFiles -includeOnlyAppIds $includeOnlyAppIds -excludeInstalledApps $installedApps -excludeRuntimePackages:$excludeRuntimePackages -WarningAction SilentlyContinue)
        $appFiles | Where-Object { $_ } | ForEach-Object {
            $appFile = $_

            if ($ShowMyCode -ne "Ignore" -or $replaceDependencies -or $replacePackageId -or $internalsVisibleTo) {
                Write-Host "Checking dependencies in $appFile"
                Replace-DependenciesInAppFile -containerName $containerName -Path $appFile -replaceDependencies $replaceDependencies -internalsVisibleTo $internalsVisibleTo -ShowMyCode $ShowMyCode -replacePackageId:$replacePackageId
            }

            if ($copyInstalledAppsToFolder) {
                if (!(Test-Path -Path $copyInstalledAppsToFolder)) {
                    New-Item -Path $copyInstalledAppsToFolder -ItemType Directory | Out-Null
                }
                Write-Host "Copy $appFile to $copyInstalledAppsToFolder"
                Copy-Item -Path $appFile -Destination $copyInstalledAppsToFolder -force
            }
        
            if (!$isCloudBcContainer) {
                if ($bcAuthContext -and $environment) {
                    $useDevEndpoint = $true
                }
                elseif ($customconfig.ServerInstance -eq "") {
                    throw "You cannot publish an app to a filesOnly container. Specify bcAuthContext and environemnt to publish to an online tenant"
                }
            }

            if ($useDevEndpoint) {
        
                if ($scope -eq "Global") {
                    throw "You cannot publish to global scope using the dev. endpoint"
                }
        
                $sslVerificationDisabled = $false
                if ($bcAuthContext -and $environment) {
                    $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
                    if ($isCloudBcContainer) {

                        throw "TODO"
                    }
                    else {
                        $devServerUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment"
                        $tenant = ""
            
                        $handler = New-Object System.Net.Http.HttpClientHandler
                        $HttpClient = [System.Net.Http.HttpClient]::new($handler)
                        $HttpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $bcAuthContext.AccessToken)
                        $HttpClient.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
                        $HttpClient.DefaultRequestHeaders.ExpectContinue = $false
                    }
                }
                else {
                    $handler = New-Object System.Net.Http.HttpClientHandler
                    if ($customConfig.DeveloperServicesSSLEnabled -eq "true") {
                        $protocol = "https://"
                    }
                    else {
                        $protocol = "http://"
                    }
                    $sslVerificationDisabled = ($protocol -eq "https://")
                    if ($sslVerificationDisabled) {
                        Write-Host "Disabling SSL Verification on HttpClient"
                        [SslVerification]::DisableSsl($handler)
                    }
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
                
                    $ip = Get-BcContainerIpAddress -containerName $containerName
                    if ($ip) {
                        $devServerUrl = "$($protocol)$($ip):$($customConfig.DeveloperServicesPort)/$($customConfig.ServerInstance)"
                    }
                    else {
                        $devServerUrl = "$($protocol)$($containerName):$($customConfig.DeveloperServicesPort)/$($customConfig.ServerInstance)"
                    }
                }
                
                $schemaUpdateMode = "synchronize"
                if ($syncMode -eq "Clean") {
                    $schemaUpdateMode = "recreate";
                }
                elseif ($syncMode -eq "ForceSync") {
                    $schemaUpdateMode = "forcesync"
                }
                $url = "$devServerUrl/dev/apps?SchemaUpdateMode=$schemaUpdateMode"
                if ($PSBoundParameters.ContainsKey('dependencyPublishingOption')) {
                    $url += "&DependencyPublishingOption=$dependencyPublishingOption"
                }
                if ($tenant) {
                    $url += "&tenant=$tenant"
                }
                
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
                        $message = "Status Code $($result.StatusCode) : $($result.ReasonPhrase)"
                        try {
                            $resultMsg = $result.Content.ReadAsStringAsync().Result
                            try {
                                $json = $resultMsg | ConvertFrom-Json
                                $message += "`n$($json.Message)"
                            }
                            catch {
                                $message += "`n$resultMsg"
                            }
                        }
                        catch {}
                        throw $message
                    }
                }
                catch {
                    GetExtendedErrorMessage -errorRecord $_ | Out-Host
                    throw
                }
                finally {
                    $FileStream.Close()
                }
            
                if ($bcContainerHelperConfig.NoOfSecondsToSleepAfterPublishBcContainerApp -gt 0) {
                    # Avoid race condition
                    Start-Sleep -Seconds $bcContainerHelperConfig.NoOfSecondsToSleepAfterPublishBcContainerApp
                }
            }
            else {
                [ScriptBlock] $scriptblock = { Param($appFile, $skipVerification, $sync, $install, $upgrade, $tenant, $syncMode, $packageType, $scope, $language, $PublisherAzureActiveDirectoryTenantId, $force, $ignoreIfAppExists)
                    $publishArgs = @{ "packageType" = $packageType }
                    if ($scope) {
                        $publishArgs += @{ "Scope" = $scope }
                        if ($scope -eq "Tenant") {
                            $publishArgs += @{ "Tenant" = $tenant }
                        }
                    }
                    if ($PublisherAzureActiveDirectoryTenantId) {
                        $publishArgs += @{ "PublisherAzureActiveDirectoryTenantId" = $PublisherAzureActiveDirectoryTenantId }
                    }
                    if ($force) {
                        $publishArgs += @{ "Force" = $true }
                    }
                    
                    $publishIt = $true
                    if ($ignoreIfAppExists) {
                        $navAppInfo = Get-NAVAppInfo -Path $appFile
                        $addArg = @{
                            "tenantSpecificProperties" = $true
                            "tenant" = $tenant
                        }
                        if ($packageType -eq "SymbolsOnly") {
                            $addArg = @{ "SymbolsOnly" = $true }
                        }
                        $appInfo = (Get-NAVAppInfo -ServerInstance $serverInstance -Name $navAppInfo.Name -Publisher $navAppInfo.Publisher -Version $navAppInfo.Version @addArg)
                        if ($appInfo) {
                            $publishIt = $false
                            Write-Host "$($navAppInfo.Name) is already published"
                            if ($appInfo.IsInstalled) {
                                $install = $false
                                $upgrade = $false
                                Write-Host "$($navAppInfo.Name) is already installed"
                            }
                        }
                    }
            
                    if ($publishIt) {
                        Write-Host "Publishing $appFile"
                        Publish-NavApp -ServerInstance $ServerInstance -Path $appFile -SkipVerification:$SkipVerification @publishArgs
                    }
        
                    if ($sync -or $install -or $upgrade) {
        
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

                        if($upgrade -and $install){
                            $navAppInfoFromDb = Get-NAVAppInfo -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant $tenant -TenantSpecificProperties
                            if($null -eq $navAppInfoFromDb.ExtensionDataVersion -or $navAppInfoFromDb.ExtensionDataVersion -eq  $navAppInfoFromDb.Version){
                                $upgrade = $false
                            } else {
                                $install = $false
                            }
                        }

                        $installArgs = @{}
                        if ($language) {
                            $installArgs += @{ "Language" = $language }
                        }
                        if ($force) {
                            $installArgs += @{ "Force" = $true }
                        }
                        if ($install) {
                            Write-Host "Installing $appName on tenant $tenant"
                            Install-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant $tenant @installArgs
                        }
                        if ($upgrade) {
                            Write-Host "Upgrading $appName on tenant $tenant"
                            Start-NavAppDataUpgrade -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant $tenant @installArgs
                        }
                    }
                }
                if ($isCloudBcContainer) {
                    $containerPath = Join-Path 'C:\DL' ([System.IO.Path]::GetFileName($appfile))
                    Copy-FileToCloudBcContainer -authContext $authContext -containerId $environment -localPath $appFile -containerPath $containerPath
                    Invoke-ScriptInCloudBcContainer `
                        -authContext $authContext `
                        -containerId $environment `
                        -ScriptBlock $scriptblock `
                        -ArgumentList $containerPath, $skipVerification, $sync, $install, $upgrade, $tenant, $syncMode, $packageType, $scope, $language, $PublisherAzureActiveDirectoryTenantId, $force, $ignoreIfAppExists
                }
                else {
                    Invoke-ScriptInBcContainer `
                        -containerName $containerName `
                        -ScriptBlock $scriptblock `
                        -ArgumentList (Get-BcContainerPath -containerName $containerName -path $appFile), $skipVerification, $sync, $install, $upgrade, $tenant, $syncMode, $packageType, $scope, $language, $PublisherAzureActiveDirectoryTenantId, $force, $ignoreIfAppExists
                }
            }
            Write-Host -ForegroundColor Green "App $([System.IO.Path]::GetFileName($appFile)) successfully published"
        }
    }
    finally {
        Remove-Item $appFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Publish-NavContainerApp -Value Publish-BcContainerApp
Export-ModuleMember -Function Publish-BcContainerApp -Alias Publish-NavContainerApp
