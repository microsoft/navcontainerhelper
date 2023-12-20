﻿<# 
 .Synopsis
  Download App Runtime Package from NAV/BC Container
 .Description
  Downloads an App runtime package to a shared folder and returns the filename of the app
 .Parameter containerName
  Name of the container from which you want to download a runtime package
 .Parameter appName
  Name of the app for which you want to download a runtime package
 .Parameter publisher
  Publisher of the app for which you want to download a runtime package
 .Parameter appVersion
  Version of the app for which you want to download a runtime package
 .Parameter tenant
  Tenant from which you want to download a runtime package
 .Parameter appFile
  Path to the location where you want the runtime package to be copied
 .Example
  $appFile = Get-BcContainerAppRuntimePackage -containerName test -appName "Image Analyzer"
#>
function Get-BcContainerAppRuntimePackage {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $appName,
        [Parameter(Mandatory=$false)]
        [string] $Publisher,
        [Parameter(Mandatory=$false)]
        [string] $appVersion,
        [Parameter(Mandatory=$false)]
        [string] $Tenant,
        [Parameter(Mandatory=$false)]
        [Boolean] $showMyCode,
        [Parameter(Mandatory=$false)]
        [Boolean] $IncludeSourceInPackageFile,
        [Parameter(Mandatory=$false)]
        [string] $appFile = (Join-Path $bcContainerHelperConfig.hostHelperFolder ("Extensions\$containerName\$appName.app" -replace '[~#%&*{}|:<>?/|"]', '_'))
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $containerAppFile = Get-BcContainerPath -containerName $containerName -path $appFile
    if ("$containerAppFile" -eq "") {
        throw "The app filename ($appFile)needs to be in a folder, which is shared with the container $containerName"
    }

    $showMyCodeExists = ($PSBoundParameters.ContainsKey('showMyCode'))
    $IncludeSourceInPackageFileExists = ($PSBoundParameters.ContainsKey('IncludeSourceInPackageFile'))

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($appName, $publisher, $appVersion, $tenant, $appFile, $showMyCodeExists, $showMyCode, $IncludeSourceInPackageFileExists, $IncludeSourceInPackageFile)

        $parameters = @{ 
            "ServerInstance" = $ServerInstance
            "Name" = $appName
            "Path" = $appFile
        }
        if ($publisher)
        {
            $parameters += @{ "Publisher" = $publisher }
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        if ($showMyCodeExists)
        {
            $parameters += @{ "showMyCode" = $showMyCode }
        }
        if ($IncludeSourceInPackageFileExists)
        {
            $parameters += @{ "IncludeSourceInPackageFile" = $IncludeSourceInPackageFile }
        }
        if ($tenant)
        {
            $parameters += @{ "Tenant" = $tenant }
        }

        Get-NavAppRuntimePackage @parameters

        $appFile

    } -ArgumentList $appName, $publisher, $appVersion, $tenant, $containerAppFile, $showMyCodeExists, $showMyCode, $IncludeSourceInPackageFileExists, $IncludeSourceInPackageFile | Select-Object -Last 1
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name Get-NavContainerAppRuntimePackage -Value Get-BcContainerAppRuntimePackage
Export-ModuleMember -Function Get-BcContainerAppRuntimePackage -Alias Get-NavContainerAppRuntimePackage
