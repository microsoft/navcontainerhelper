<# 
 .Synopsis
  Function for resolving dependencies using an AzureFeed
 .Description
  Function for resolving dependencies using an AzureFeed
  To being able to resolve dependencies an artifact must be in the following format.
  The app id must be in the artifact name so apps will be identified correctly.
  The artifact can contain an .runtime.app file. If no app.json or .app file is present the .runtime.app fill be treated as a leaf in the tree.
  If an app.json is present dependencies will be take from that file.
  If no app.json but an .app file is present that will be extracted and used to find dependencies
 .Parameter organization
  Devops organization url
 .Parameter feed
  AzArtifacts Feed to resolve the dependencies
 .Parameter appsFolder
  Root folder used to resolve the dependencies
 .Parameter outputFolder
  Folder where all dependencies will be copied to
 .Parameter lvl
  Level to track recursion depth.
    
#>
function Resolve-DependenciesFromAzureFeed {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $organization,
        [Parameter(Mandatory = $true)]
        [string] $feed,
        [Parameter(Mandatory = $true)]
        [string] $appsFolder,
        [Parameter(Mandatory = $false)]
        [string] $pat = '',
        [string] $outputFolder = (Join-Path $appsFolder '.alpackages'),
        [switch] $runtimePackages,
        [int] $lvl = -1,
        [string[]] $ignoredDependencies = @()
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    if($pat -ne '') {
        Write-Warning "Enviroment Variable AZURE_DEVOPS_EXT_PAT is overridden";
        $env:AZURE_DEVOPS_EXT_PAT = $pat
    }
    $spaces = ''
    $lvl++

    For ($i = 0; $i -le $lvl; $i++) {
        $spaces += '   '
    }

    # Create outputFolder if not exits
    if (!(Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
    }

    # Search for app.jsons
    $apps = @(Get-ChildItem -Path (Join-Path $appsFolder '/*/app.json'))
    if ($apps.Count -eq 0) {
        # Look for a single app.json in root
        try {
            $apps = @(Get-ChildItem -Path (Join-Path $appsFolder '/app.json'))
        }
        catch {}
    }
    if ($apps.Count -eq 0) {
        # If no app.jsons found look for .app files.
        $apps = @(Get-ChildItem -Path (Join-Path $appsFolder '*.app') -Exclude '*.runtime.app')
    }

    Write-Host "$($spaces)$($apps.Count) apps found";

    $apps | % {

        if ($_.Name -eq "app.json") {
            Write-Host "$($spaces)$($_.DirectoryName | Split-Path -Leaf)"
        }
        else {
            Write-Host "$($spaces)$($_.Name)"
        }
        # Create temp folders
        $tempAppFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        $tempAppDependenciesFolder = Join-Path $tempAppFolder 'dependencies'
        try {
            New-Item -path $tempAppFolder -ItemType Directory -Force | Out-Null
            New-Item -path $tempAppDependenciesFolder -ItemType Directory -Force | Out-Null
            # Read app.json
            if ($_.Extension -eq ".app") {
                $tempAppSourceFolder = Join-Path $tempAppFolder 'source'
                New-Item -path $tempAppSourceFolder -ItemType Directory -Force | Out-Null

                Extract-AppFileToFolder -appFilename $_ -generateAppJson -appFolder $tempAppSourceFolder 6>$null

                $appJson = [System.IO.File]::ReadAllLines((Join-Path $tempAppSourceFolder "app.json")) | ConvertFrom-Json
            }
            else {
                $appJson = [System.IO.File]::ReadAllLines($_) | ConvertFrom-Json
            }
            if ($appJson.psobject.Properties.name -contains "id" -and $lvl -eq 0) {
                $ignoredDependencies += $appJson.Id
                Write-Host "Added $($appJson.Id) to ignored apps";
            }
            if ($appJson.psobject.Properties.name -contains "dependencies") {
                #Resolving dpendencies
                $appJson.dependencies | % {
                    if ($_.psobject.Properties.name -contains "id") {
                        $id = $_.id
                    } elseif($_.psobject.Properties.name -contains "appId") {
                        $id = $_.appId
                    }
                    if ($null -ne $id) {
                        if ($id -notin $ignoredDependencies) {
                            try {
                                $tempAppDependencyFolder = Join-Path $tempAppDependenciesFolder $id
                                New-Item -path $tempAppDependencyFolder -ItemType Directory -Force | Out-Null
                                Write-Host "$($spaces)Downloading: $($id)"
                                if ( $(az artifacts universal download `
                                            --organization $organization `
                                            --feed $feed `
                                            --name $id `
                                            --version (AzureFeedWildcardVersion -appVersion $_.version) `
                                            --path $tempAppDependencyFolder >$null 2>&1; $?)) {
                                    Write-Host "$($spaces)Downloaded!"
                                }
            
        
                                $dependencyApp = @(Get-ChildItem -Path (Join-Path $tempAppDependencyFolder '*.app') -Exclude '*.runtime.app')
                                $dependencyRuntimeApp = @(Get-ChildItem -Path (Join-Path $tempAppDependencyFolder '*.runtime.app'))

                                $hasDependencyApp = $dependencyApp.Count -gt 0
                                $hasDependencyRuntimeApp = $dependencyRuntimeApp.Count -gt 0
                                if ($hasDependencyApp -or $hasDependencyRuntimeApp) {
                                    if($hasDependencyRuntimeApp -and ($runtimePackages -or (-not $hasDependencyApp))) {
                                        $dep = $dependencyRuntimeApp[0]
                                    } else {
                                        $dep = $dependencyApp[0]
                                    }
                                    if (!(Test-Path (Join-Path $outputFolder $dep.Name))) {
                                        Copy-Item -Path $dep -Destination $outputFolder -Force

                                        Write-Host "$($spaces)Copied to $($outputFolder)"

                                        Resolve-DependenciesFromAzureFeed -organization $organization -feed $feed -outputFolder $outputFolder -appsFolder $tempAppDependencyFolder -lvl $lvl -runtimePackages:$runtimePackages
                                    }
                                    else {
                                        Write-Host "$($spaces)$($dep.Name) exists"
                                    }
                                }
                            }
                            catch {
                                Write-Warning "$($spaces) Cannot find the package $($id)"
                            }
                        } else {
                            Write-Warning "$($id) is ignored"
                        }
                    }   
                }
                if ($appJson.dependencies.Count -eq 0) {
                    Write-Host "$($spaces)No more dependencies."
                }
            }
        
        }
        finally {
            Remove-Item -Path $tempAppFolder -Recurse -Force -ErrorAction SilentlyContinue
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
Export-ModuleMember -Function Resolve-DependenciesFromAzureFeed
