<# 
 .Synopsis
  Get App Info from NAV/BC Container
 .Description
  Creates a session to the NAV/BC Container and runs the CmdLet Get-NavAppInfo in the container
 .Parameter containerName
  Name of the container in which you want to enumerate apps (default navserver)
 .Parameter tenant
  Specifies the tenant from which you want to get the app info
 .Parameter tenantSpecificProperties
  Specifies whether you want to get the tenant specific app properties
 .Parameter symbolsOnly
  Specifies whether you only want apps, which are of packagetype SymbolsOnly (Specifying SymbolsOnly ignores the tenant parameter)
 .Example
  Get-NavContainerAppInfo -containerName test2
 .Example
  Get-NavContainerAppInfo -containerName test2 -tenant mytenant -tenantSpecificProperties
 .Example
  Get-NavContainerAppInfo -containerName test2 -symbolsOnly
#>
function Get-NavContainerAppInfo {
    Param(
        [string] $containerName = "navserver",
        [string] $tenant = "",
        [switch] $symbolsOnly,
        [switch] $tenantSpecificProperties,
        [ValidateSet('None','DependenciesFirst','DependenciesLast')]
        [string] $sort = 'None'
    )

    $args = @{}
    if ($symbolsOnly) {
        $args += @{ "SymbolsOnly" = $true }
    } else {
        $args += @{ "TenantSpecificProperties" = $tenantSpecificProperties }
        if ("$tenant" -eq "") {
            $tenant = "default"
        }
        $args += @{ "Tenant" = $tenant }
    }

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($inArgs, $sort)

        $script:installedApps = @()

        function AddAnApp { Param($anApp) 
            $alreadyAdded = $script:installedApps | Where-Object { $_.AppId -eq $anApp.AppId -and $_.name -eq $anApp.name -and $_.publisher -eq $anApp.publisher -and $_.version -eq $anApp.version }
            if (-not ($alreadyAdded)) {
                AddDependencies -anApp $anApp
                $script:installedApps += $anApp
            }
        }
    
        function AddDependency { Param($dependency)
            $dependentApp = $apps | Where-Object { $_.AppId -eq $dependency.AppId -and $_.name -eq $dependency.name -and $_.publisher -eq $dependency.publisher -and $_.version -eq $dependency.version }
            if ($dependentApp) {
                AddAnApp -AnApp $dependentApp
            }
        }
    
        function AddDependencies { Param($anApp)
            if (($anApp) -and ($anApp.Dependencies)) {
                $anApp.Dependencies | % { AddDependency -Dependency $_ }
            }
        }

        $apps = Get-NavAppInfo -ServerInstance $ServerInstance @inArgs | ForEach-Object { Get-NavAppInfo -ServerInstance $serverInstance -id $_.AppId -publisher $_.publisher -name $_.name -version $_.Version @inArgs }
        if ($sort -eq "None") {
            $apps
        }
        else {
            $apps | ForEach-Object { AddAnApp -AnApp $_ }
            if ($sort -eq "DependenciesLast") {
                [Array]::Reverse($script:installedApps)
            }
            $script:installedApps
        }

    } -ArgumentList $args, $sort | Where-Object {$_ -isnot [System.String]}
}
Set-Alias -Name Get-BCContainerAppInfo -Value Get-NavContainerAppInfo
Export-ModuleMember -Function Get-NavContainerAppInfo -Alias Get-BCContainerAppInfo
