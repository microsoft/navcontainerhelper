﻿<# 
 .Synopsis
  Get App Info from NAV/BC Container
 .Description
  Creates a session to the NAV/BC Container and runs the CmdLet Get-NAVAppInfo in the container
 .Parameter containerName
  Name of the container in which you want to enumerate apps
 .Parameter tenant
  Specifies the tenant from which you want to get the app info
 .Parameter tenantSpecificProperties
  Specifies whether you want to get the tenant specific app properties
 .Parameter symbolsOnly
  Specifies whether you only want apps, which are of packagetype SymbolsOnly (Specifying SymbolsOnly ignores the tenant parameter)
 .Parameter sort
  Specifies how (if any) you want to sort apps based on dependencies to other apps
 .Parameter publishedOnly
  Get published apps
 .Parameter useNewFormat
  Get published apps
 .Parameter appFilePath
  Specifies the path to a Business Central app package file (N.B. the path should be shared with the container)
 .Example
  Get-BcContainerAppInfo -containerName test2
 .Example
  Get-BcContainerAppInfo -containerName test2 -tenant mytenant -tenantSpecificProperties
 .Example
  Get-BcContainerAppInfo -containerName test2 -symbolsOnly
 .Example
  Get-BcContainerAppInfo -containerName test2 -appFilePath "C:\ProgramData\BcContainerHelper\Extensions\apx-dev\myApp.app"
#>
function Get-BcContainerAppInfo {
    Param (
        [Parameter(Position=0)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory = $false, ParameterSetName = 'Original')]
        [string] $tenant = "",
        [Parameter(Mandatory = $true, ParameterSetName = 'AppFile')]
        [string] $appFilePath,
        [Parameter(Mandatory = $false, ParameterSetName = 'Original')]
        [switch] $symbolsOnly,
        [Parameter(Mandatory = $false, ParameterSetName = 'Original')]
        [switch] $tenantSpecificProperties,
        [Parameter(Mandatory = $false, ParameterSetName = 'Original')]
        [ValidateSet('None','DependenciesFirst','DependenciesLast')]
        [string] $sort = 'None',
        [Parameter(Mandatory = $false, ParameterSetName = 'Original')]
        [switch] $publishedOnly,
        [Parameter(Mandatory = $false, ParameterSetName = 'Original')]
        [switch] $installedOnly,
        [Parameter(Mandatory = $false)]
        [switch] $useNewFormat = $bcContainerHelperConfig.UseNewFormatForGetBcContainerAppInfo
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $args = @{}
    if ($appFilePath) {
        $containerAppFilePath = Get-BcContainerPath -containerName $containerName -path $appFilePath -throw
        $args += @{ "Path" = $containerAppFilePath }
    }
    elseif ($symbolsOnly) {
        $args += @{ "SymbolsOnly" = $true }
    }
    elseif (!$publishedOnly) {
        if ($installedOnly) {
            $tenantSpecificProperties = $true
        }
        $args += @{ "TenantSpecificProperties" = $tenantSpecificProperties }
        if ("$tenant" -eq "") {
            $tenant = "default"
        }
        $args += @{ "Tenant" = $tenant }
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($inArgs, $sort, $installedOnly, $useNewFormat)

        $script:installedApps = @()

        function AddAnApp { Param($anApp)
            #Write-Host "AddAnApp $($anapp.Name) $($anapp.Version)"
            $alreadyAdded = $script:installedApps | Where-Object { $_.AppId -eq $anApp.AppId -and $_.Version -eq $anApp.Version }
            if (-not ($alreadyAdded)) {
                #Write-Host "add dependencies"
                AddDependencies -anApp $anApp
                #Write-Host "add the app $($anapp.Name)"
                $script:installedApps += $anApp
            }
        }

        function AddDependency { Param($dependency)
            #Write-Host "Add Dependency $($dependency.Name) $($dependency.Version)"
            $dependentApp = $apps | Where-Object { "$($_.AppId)" -eq "$($dependency.AppId)"  }
            if ($dependentApp) {
                @($dependentApp) | ForEach-Object { AddAnApp -AnApp $_ }
            }
        }

        function AddDependencies { Param($anApp)
            #Write-Host "Add Dependencies for $($anApp.Name)"
            if (($anApp) -and ($anApp.Dependencies)) {
                $anApp.Dependencies | % { AddDependency -Dependency $_ }
            }
        }

        if ($inArgs.ContainsKey("Path")) {
            $apps = Get-NAVAppInfo @inArgs
        }
        else {
            $inArgs += @{ "ServerInstance" = $ServerInstance }
            $apps = Get-NAVAppInfo @inArgs | Where-Object { (!$installedOnly) -or ($_.IsInstalled -eq $true) } | ForEach-Object { Get-NAVAppInfo -id "$($_.AppId)" -publisher $_.publisher -name $_.name -version $_.Version @inArgs }
        }

        if ($sort -ne "None") {
            $apps | ForEach-Object { AddAnApp -AnApp $_ }
            $apps = $script:installedApps
            if ($sort -eq "DependenciesLast") {
                [Array]::Reverse($apps)
            }
        }
        if (!$useNewFormat) {
            $apps
        }
        else {
            $apps | ForEach-Object { 
                $app = $_
                $newApp = [ordered]@{}
                $app.PSObject.Properties.Name | ForEach-Object {
                    if ($_ -eq "Dependencies" -or $_ -eq "Screenshots" -or $_ -eq "Capabilities") {
                        $v = @($app."$_")
                        $newApp."$_" = ConvertTo-Json -InputObject $v -Depth 1 -Compress
                    }
                    elseif ($app."$_") {
                        if ($app."$_" -is [string] -or $app."$_" -is [System.Version] -or $app."$_" -is [boolean]) {
                            $newApp."$_" = $app."$_"
                        }
                        else {
                            $newApp."$_" = "$($app."$_")"
                        }
                    }
                }
                $newApp
            }
        }
    } -ArgumentList $args, $sort, $installedOnly, $useNewFormat | Where-Object {$_ -isnot [System.String]} | ForEach-Object {
        $app = $_
        if (!$useNewFormat) {
            $app
        }
        else {
            $newApp = [ordered]@{}
            $app.Keys | ForEach-Object {
                if ($_ -eq "Dependencies" -or $_ -eq "Screenshots" -or $_ -eq "Capabilities") {
                    $newApp."$_" = @($app."$_" | ConvertFrom-Json | ForEach-Object { if ($_) { $_ } } )
                }
                else {
                    $newApp."$_" = $app."$_"
                }
            }
            [PSCustomObject]$newApp
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
Set-Alias -Name Get-NavContainerAppInfo -Value Get-BcContainerAppInfo
Export-ModuleMember -Function Get-BcContainerAppInfo -Alias Get-NavContainerAppInfo
