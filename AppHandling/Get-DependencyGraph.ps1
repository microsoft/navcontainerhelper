class App {
   [String]$id
   [String]$name
   [String]$version
   [String]$path
   [hashtable[]]$dependencies = @()
   [boolean]$isInstalled = $false
   [boolean]$isPublished = $false

   [boolean] IsNewerThen([App] $compare) {
        return $this.version -eq (Get-NewerVersion -versionA $this.version -versionB $compare.version)
   }
   
   App($appInfo, $dependencyFilter = { $true }) {
        $this.id = $appInfo.AppId
        $this.name = $appInfo.Name
        $this.version = $appInfo.Version
        $this.dependencies = @($appInfo.Dependencies | Where-Object $dependencyFilter | % { 
            @{ 
                Id = $_.AppId
                Version = $_.MinVersion
            }
        })

        if($appInfo.psobject.Properties.name -contains "path") {
            $this.path = $appInfo.path
        }
        
        if($appInfo.psobject.Properties.name -contains "IsInstalled" -and $null -ne $appInfo.IsInstalled) {
            $this.isInstalled = $appInfo.IsInstalled
        }
        
        if($appInfo.psobject.Properties.name -contains "IsPublished" -and $null -ne $appInfo.IsPublished) {
            $this.isPublished = $appInfo.IsPublished
        }
   }
}

class DependencyGraph {
    $apps = @{}

    AddApp([App] $app) {
        $appVersions = $this.apps[$app.id]
        if($null -ne $appVersions -and $appVersions.Length -gt 0) {
            if($app.IsNewerThen($appVersions[0])) {
                $this.apps[$app.id] = @($app) + $appVersions
            } else {
                $this.apps[$app.id] += @($app)
            }
        } else {
            $this.apps[$app.id] = @($app)
        }
    }

    [App] GetLatestVersion([String] $appId) {
        $appVersions = $this.apps[$appId]
        if($null -ne $appVersions -and $appVersions.Length -gt 0) {
            return $appVersions[0]
        }
        return $null
    }

    [App[]] GetAllVersions([String] $appId) {
        $appVersions = $this.apps[$appId]
        if($null -ne $appVersions -and $appVersions.Length -gt 0) {
            return $appVersions
        }
        return $null
    }

    [App] GetNewerVersionThen($appId, $minVersion) {
        $appVersions = $this.GetAllVersions($appId)
        if($null -ne $appVersions) {
            $filteredVersions = @($appVersions | Where-Object {
                $newest = Get-NewerVersion -versionA $minVersion -versionB $_.Version
                ($newest -eq $_.Version) -or ($null -eq $newest)
            })
            if($null -ne $filteredVersions) {
                return $filteredVersions[0]
            }
        }
        return $null
    }

    [String[]] GetAllAppIds() {
        return $this.apps.keys
    }
    
    [App[]] GetAllLatestVersions() {
        return $this.apps.keys | % { $this.GetLatestVersion($_) }
    }

    [hashtable[]] GetDependencies([String] $appId, [String] $minVersion) {
        $appVersions = $this.apps[$appId]

        $dependencies = @()
        $app = $this.GetNewerVersionThen($appId, $minVersion)
        if($null -ne $appVersions) {

            # Filter all app versions that are newer then $minVersion then take the newest
            $app = $appVersions | Where-Object {
                $newest = Get-NewerVersion -versionA $minVersion -versionB $_.Version
                $newest -eq $_.Version -or $null -eq $newest
            }[0]
            if($null -ne $app){
                foreach($edge in $app.dependencies) {
                    $deps = $this.GetDependencies($edge.Id, $edge.Version)
                    $depIds = $dependencies | % { $_.Id }
                    foreach($dep in $deps) {
                        if($depIds -notcontains $dep.Id) {
                            $dependencies += $dep
                        }
                    }
                    if($depIds -notcontains $edge.Id) {
                        $dependencies += $edge
                    }
                }
            }
        }
        return $dependencies
    }

    [hashtable[]] GetDependents([String] $appId, [String] $minVersion) {
        function Get-MatchingVersion {
            param (
                $appVersions,
                $appId,
                $appVersion
            )
            foreach($app in $appVersions) {
                foreach($dependency in $app.dependencies){
                    $newest = (Get-NewerVersion -versionA $dependency.Version -versionB $appVersion)
                    if(($dependency.Id -eq $appId) -and ($newest -eq $appVersion -or $null -eq $newest)) {
                        return  @{ 
                            Id = $app.Id
                            Version = $app.Version
                        }
                    } 
                }
            }
            return $null
        }

        $dependents = @()
        $outerApp = $this.GetNewerVersionThen($appId, $minVersion)

        if($null -ne $outerApp){
    
            foreach($innerAppVersions in $this.apps.Values) {
                $innerAppVersion = Get-MatchingVersion -appVersions $innerAppVersions -appId $appId -appVersion $minVersion
                if($null -ne $innerAppVersion) {
                    $deps = $this.GetDependents($innerAppVersion.id, $innerAppVersion.Version)

                    if(($dependents | % { $_.Id }) -notcontains $innerAppVersion.Id) {
                        $dependents += $innerAppVersion
                    }

                    foreach($dep in $deps) {
                        if(($dependents | % { $_.Id }) -notcontains $dep.Id) {
                            $dependents += $dep
                        }
                    }
                }
            }
        }

        return $dependents
    }
    [void] draw() {
        foreach($appId in $this.apps.Keys) {
            foreach($appVersion in $this.apps[$appId]) {
                Write-Host -ForegroundColor Yellow "$($appVersion.Name) $($appVersion.Version)"

                Write-Host -ForegroundColor Magenta "Dependencies"
                foreach($appDep in $this.GetDependencies($appVersion.Id, $appVersion.Version)) {
                    Write-Host -ForegroundColor Magenta " - $($appDep.Id) $($appDep.Version)"
                }

                Write-Host -ForegroundColor Green "Dependents"
                foreach($appDep in $this.GetDependents($appVersion.Id, $appVersion.Version)) {
                    Write-Host -ForegroundColor Green " - $($appDep.Id) $($appDep.Version)"
                }

            }
        }
    }
}
function Get-NewerVersion {
    param(
        [String]$versionA,
        [String]$versionB
    )

    $aParts = $versionA.Split('.') | % { $_ -as [int]}
    $bParts = $versionB.Split('.') | % { $_ -as [int]}
    for($i = 0; $i -lt $aParts.Length; $i++) {
        $aPart = $aParts[$i]
        $bPart = $bParts[$i]

        if($aPart -gt $bPart) {
            return $versionA
        } elseif($bPart -gt $aPart) {
            return $versionB
        }
    }

    return $null
}
<# 
 .Synopsis
  Get Dependency Graph for BC Apps from AppInfo
 .Description
  Creates a dependency graph from appInfos.
 .Parameter appInfos
  Specifies the appInfo of a Business Central app 
 .Example
  Get-DependencyGraph --appInfos @{
                    AppId = "10veedas-1acc-460a-9c07-e110dc216540"
                    Version = "20.0.0.1"
                    Publisher = "BEYONDIT GmbH"
                    Name = "Test App"
                    Dependencies = @(
                    )
                },
#>
function Get-DependencyGraphFromAppInfos {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]] $appInfos,
        [switch] $ignoreMicrosoftApps,
        [Parameter(Mandatory = $false)]
        [scriptblock] $filter = { $true }
    )

    $dependencyGraph = [DependencyGraph]::new()

    $microsoftFilter = { $_.Publisher -ne "Microsoft" }

    if(($ignoreMicrosoftApps -eq $true)) {
        $usedFilter = [ScriptBlock]::Create($microsoftFilter.ToString() + " -and " + $filter.ToString())
    } else {
        $usedFilter = $filter
    }

    foreach ($appInfo in $appInfos) {
        $app = [App]::new($appInfo, $usedFilter)
        $dependencyGraph.AddApp($app)
    }

    return $dependencyGraph
}

<# 
 .Synopsis
  Get Dependency Graph for BC Apps
 .Description
  Creates a dependency graph for app files or apps in an container.
 .Parameter containerName
  Name of the container in which you want to enumerate apps
 .Parameter tenant
  Specifies the tenant from which you want to get the app info
 .Parameter appPaths
  Specifies the path to a Business Central app package files (N.B. the path should be shared with the container)
 .Example
  Get-DependencyGraph -containerName test2
 .Example
  Get-DependencyGraph -containerName test2 -tenant mytenant
 .Example
  Get-DependencyGraph -containerName test2 --appPaths @(".\Example.app", ".\Hello.app")
#>
function Get-DependencyGraph {
    param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory = $false)]
        [string] $tenant = "",
        [Parameter(Mandatory = $false)]
        [string[]] $appPaths = $null,
        [switch] $ignoreMicrosoftApps,
        [Parameter(Mandatory = $false)]
        [scriptblock] $filter = { $true }
    )


    if($null -ne $appPaths) {
        $appInfos = @()
        foreach ($appPath in $appPaths) {
            $appInfo = Get-BcContainerAppInfo -useNewFormat -containerName $containerName -appFilePath $appPath
            $appInfo.path = $appPath
            
            $appInfos += $appInfo
        }
        
    } else {
        $appInfos = Get-BcContainerAppInfo -useNewFormat -containerName $containerName -tenant $tenant -tenantSpecificProperties | Where-Object $usedFilter
    }
    

    return Get-DependencyGraphFromAppInfos -ignoreMicrosoftApps $ignoreMicrosoftApps -filter $filter -appInfos $appInfos
}

Export-ModuleMember -Function Get-DependencyGraph
Export-ModuleMember -Function Get-DependencyGraphFromAppInfos