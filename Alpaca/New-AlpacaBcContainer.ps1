<#
 .SYNOPSIS
  Creates a new Alpaca container.
    .DESCRIPTION
    Creates a new Alpaca container.
    .PARAMETER authContext
    Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
    .PARAMETER artifactUrl
    Url to the artifact to use for the container.
    .PARAMETER licenseFileUrl
    Url to the license file to use for the container.
    .PARAMETER devContainer
    If specified, the container will be created as a dev container.
    .PARAMETER containerName
    Name of the container.
    .PARAMETER sourceLabel
    Source Label to use for the container.
    .PARAMETER environmentVariables
    Additional environment variables to set for the container.
    .PARAMETER additionalLabels
    Additional labels to set for the container.
    .PARAMETER additionalFolders
    Additional folders to mount for the container.
    .PARAMETER credential
    Credential to use for the container.
    .PARAMETER enableSymbolLoading
    If specified, symbol loading will be enabled for the container.
    .PARAMETER enablePremium
    If specified, premium will be enabled for the container.
    .PARAMETER enablePerformanceCounter
    If specified, performance counter will be enabled for the container.
    .PARAMETER publishSwaggerUI
    If specified, swagger UI will be published for the container.
    .PARAMETER autoStartTime
    Time to start the container automatically (local timezone)
    .PARAMETER autoStartTimeUTC
    Time to start the container automatically (UTC)
    .PARAMETER autoStartMode
    Mode to start the container automatically
    .PARAMETER autoStopTime
    Time to stop the container automatically (local timezone)
    Can be one of: 'deactivated','daily','weekdays' or 'once'
    .PARAMETER autoStopTimeUTC
    Time to stop the container automatically (UTC)
    .PARAMETER autoStopMode
    Mode to stop the container automatically
    Can be one of: 'daily', 'deactivated' or 'deactivated once'
    .PARAMETER doNotWait
    If specified, the function will not wait for the container to be ready.
    .EXAMPLE
    $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
    $artifactUrl = Get-BCArtifactUrl -country us -select Weekly
    $credential = New-Object pscredential -ArgumentList 'admin', $securePassword
    $containerId = New-AlpacaBcContainer `
        -authContext $authContext `
        -artifactUrl $artifactUrl `
        -credential $credential `
        -containerName 'bcserver' `
        -doNotWait `
        -devContainer
    Wait-AlpacaBcContainerReady `
        -authContext $authContext `
        -containerId $containerId
#>
function New-AlpacaBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $artifactUrl,
        [string] $licenseFileUrl = '',
        [switch] $devContainer,
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $sourceLabel = 'BcContainerHelper',
        [string[]] $environmentVariables = @(),
        [hashTable] $additionalLabels = @{},
        [string[]] $additionalFolders = @(),
        [PSCredential] $credential,
        [switch] $enableSymbolLoading,
        [switch] $enablePremium,
        [switch] $enablePerformanceCounter,
        [switch] $publishSwaggerUI,
        [string] $autoStartTime = '08:00',
        [string] $autoStartTimeUTC = [datetime]::ParseExact($autoStartTime,'H:mm',[CultureInfo]::InvariantCulture).ToUniversalTime().ToString('HH:mm'),
        [ValidateSet('deactivated','daily','weekdays','once')]
        [string] $autoStartMode = "$(if($devContainer){"weekdays"}else{"deactivated"})",
        [string] $autoStopTime = '18:00',
        [string] $autoStopTimeUTC = [datetime]::ParseExact($autoStopTime,'H:mm',[CultureInfo]::InvariantCulture).ToUniversalTime().ToString('HH:mm'),
        [ValidateSet('daily','deactivated','deactivated once')]
        [string] $autoStopMode = "$(if($devContainer){"daily"}else{"deactivated"})",
        [switch] $doNotWait
    )

    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Service/bc"

    # Set default AZP_SERVICE_DISPLAYNAME (can be overridden in $environmentVariables)
    $environmentVariables = @( "AZP_SERVICE_DISPLAYNAME=$containerName" ) + $environmentVariables
    $additionalLabels.Source = $sourceLabel
    # Set Alpaca additional Folder for c:\run first - can be overridden in $additionalFolders
    if ($devContainer) {
        $typeStr = 'dev'
    }
    else {
        $typeStr = 'build'
    }
    $runFolderUrl = [string]::Format($bcContainerHelperConfig.AlpacaSettings.RunFolderUrl,$typeStr,$bcContainerHelperConfig.AlpacaSettings.ApiVersion)
    $additionalFolders = @( "c:\run=$runFolderUrl" ) + $additionalFolders

    $parameters = [ordered]@{
        "persistence" = $devContainer.IsPresent
        "environmentVars" = $environmentVariables
        "additionalLabels" = $additionalLabels
        "additionalFolders" = $additionalFolders
        "licenseFile" = $licenseFileUrl
        "bcArtifact" = @{
            "storageAccount" = $artifactUrl.Split('/')[2].Split('.')[0]
            "type" = $artifactUrl.Split('/')[3]
            "version" = $artifactUrl.Split('/')[4]
            "country" = $artifactUrl.Split('/')[5]
        }
        "userName" = $credential.UserName
        "password" = $credential.Password | Get-PlainText
        "enableSymbolLoading" = $enableSymbolLoading.IsPresent
        "enablePremium" = $enablePremium.IsPresent
        "enablePerformanceCounter" = $enablePerformanceCounter.IsPresent
        "publishSwaggerUI" = $publishSwaggerUI.IsPresent
        "autoStartInfo" = @{
            "time" = $autoStartTimeUTC
            "mode" = @('deactivated','daily','weekdays','once').IndexOf($autoStartMode)
        }
        "autoStopInfo" = @{
            "time" = $autoStopTimeUTC
            "mode" = @('daily','deactivated','deactivated once').IndexOf($autoStopMode)
        }
    }
    Write-Host "Requesting new Alpaca container"
    $response = Invoke-RestMethod -Method POST -Uri $Uri -Body (ConvertTo-Json $parameters) -Headers $headers
    $containerId = $response.serviceId
    Write-Host "Request submitted, containerId=$containerId"
    if (!$doNotWait) {
        Wait-AlpacaBcContainerReady -authContext $authContext -containerId $containerId
    }
    $containerId
}
Export-ModuleMember -Function New-AlpacaBcContainer
