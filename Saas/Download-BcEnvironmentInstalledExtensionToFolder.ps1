<#
 .Synopsis
  Function for downloading Installed Extensions (symbols) from an online Business Central environment (both AppSource and PTEs)
 .Description
  Function for downloading Installed Extensions (symbols) from an online Business Central environment (both AppSource and PTEs)
 .Parameter bcAuthContext
  Authorization Context created by New-BcAuthContext. 
 .Parameter environment
  Environment from which you want to return the published Apps.
 .Parameter apiVersion
  API version. Default is v2.0.
 .Parameter folder
  Folder in which the symbols of dependent apps will be placed. Default is $appProjectFolder\symbols.   
 .Parameter appPublisher
  Publisher of the app you want to download
 .Parameter appName
  Name of the app you want to download
 .Parameter appVersion
  Version of the app you want to download
 .Parameter appId
  Id of the app you want to download
 .EXAMPLE
  $appSymbolsFolder = Join-Path $compilerFolder 'symbols'
  $bcAuthContext = New-BcAuthContext -includeDeviceLogin -tenantID $tenant
  $publishedApps = (Get-BcEnvironmentInstalledExtensions -bcAuthContext $bcAuthContext -environment $environment | ForEach-Object { @{ "Publisher" = $_.Publisher; "Name" = $_.displayName; "Id" = $_.Id; "Version" = [System.Version]::new($_.VersionMajor, $_.VersionMinor, $_.VersionBuild, $_.VersionRevision) } })
  foreach ($app in $publishedApps) {
    Download-BcEnvironmentInstalledExtensionToFolder -bcAuthContext $bcAuthContext -environment $environment -appName $app.Name -appId $app.Id -appVersion $app.Version -appPublisher $app.Publisher -folder $appSymbolsFolder
  }
  Download-BcEnvironmentInstalledExtensionToFolder -bcAuthContext $bcAuthContext -environment $environment -appName "System" -appVersion "1.0.0.0" -appPublisher "Microsoft" -folder $appSymbolsFolder
#>
function Download-BcEnvironmentInstalledExtensionToFolder {
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable] $bcAuthContext,       
        [string] $environment,
        [string] $apiVersion = "v2.0",
        [Parameter(Mandatory = $true)]
        [alias('appSymbolsFolder')]
        [string] $folder,
        [Parameter(Mandatory = $true)]
        [string] $appPublisher,
        [Parameter(Mandatory = $true)]
        [string] $appName,
        [Parameter(Mandatory = $true)]        
        [string] $appVersion = '0.0.0.0',
        [Parameter(Mandatory = $false)]
        [string] $appId
    )
    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $bearerAuthValue = "Bearer $($bcAuthContext.AccessToken)"
        $headers = @{ "Authorization" = $bearerAuthValue }

        #WARNING: The file name downloaded may not match the one on the server, as the server only returns the file's content. When requesting the file, I specify the name, publisher, version, and even the ID, but only the ID remains consistent.
        $symbolsName = "$($appPublisher)_$($appName)_$($appVersion).app".Split([System.IO.Path]::GetInvalidFileNameChars()) -join ''
        Write-Host "Downloading symbols: $symbolsName"

        $symbolsFile = (Join-Path $folder $symbolsName)
        Write-Host "symbolsFile: $symbolsFile"

        $devServerUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/$apiVersion/$environment"

        if ($appId) {
            $url = "$devServerUrl/dev/packages?appId=$($appId)&versionText=$($appVersion)"
        }
        else {
            $url = "$devServerUrl/dev/packages?publisher=$($appPublisher)&appName=$($appName)&versionText=$($appVersion)"
        }

        Write-Host "url: $url"       

        try {
            DownloadFileLow -sourceUrl $url -destinationFile $symbolsFile -Headers $headers
        }
        catch {
            $throw = $true            
            if ($throw) {
                Write-Host "ERROR $($_.Exception.Message)"
                throw (GetExtendedErrorMessage $_)
            }
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
Export-ModuleMember -Function Download-BcEnvironmentInstalledExtensionToFolder
