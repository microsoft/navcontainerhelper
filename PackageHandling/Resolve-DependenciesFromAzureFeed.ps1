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
        [string] $outputFolder = (Join-Path $appsFolder '.alpackages'),
        [int] $lvl = -1
    )
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
        $tempAppFolder = Join-Path ((Get-Item -Path $env:temp).FullName) ([Guid]::NewGuid().ToString())
        $tempAppDependenciesFolder = Join-Path $tempAppFolder 'dependencies'
        try {
            New-Item -path $tempAppFolder -ItemType Directory -Force | Out-Null
            New-Item -path $tempAppDependenciesFolder -ItemType Directory -Force | Out-Null
            # Read app.json
            if ($_.Extension -eq ".app") {
                $tempAppSourceFolder = Join-Path $tempAppFolder 'source'
                New-Item -path $tempAppSourceFolder -ItemType Directory -Force | Out-Null

                Extract-AppFileToFolder -appFilename $_ -generateAppJson -appFolder $tempAppSourceFolder 6>$null

                $appJson = Get-Content (Join-Path $tempAppSourceFolder "app.json") | ConvertFrom-Json
            }
            else {
                $appJson = Get-Content $_ | ConvertFrom-Json
            }
            if ($appJson.psobject.Properties.name -contains "dependencies") {
                #Resolving dpendencies
                $appJson.dependencies | % {
                    if ($_.psobject.Properties.name -contains "id") {
                        $id = $_.id
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
        
    
                            $dependency = @(Get-ChildItem -Path (Join-Path $tempAppDependencyFolder '*.app') -Exclude '*.runtime.app')
                            if ($dependency.Count -eq 0) {
                                $dependency = @(Get-ChildItem -Path (Join-Path $tempAppDependencyFolder '*.runtime.app'))
                            }
                            if ($dependency.Count -gt 0) {
                                $dep = $dependency[0]
                                if (!(Test-Path (Join-Path $outputFolder $dep.Name))) {
                                    Copy-Item -Path $dep -Destination $outputFolder -Force

                                    Write-Host "$($spaces)Copied to $($outputFolder)"

                                    Resolve-DependenciesFromAzureFeed -organization $organization -feed $feed -outputFolder $outputFolder -appsFolder $tempAppDependencyFolder -lvl $lvl
                                }
                                else {
                                    Write-Host "$($spaces)$($dep.Name) exists"
                                }
                            } 
                        }
                        catch {
                            Write-Warning "$($spaces) Cannot find the package $($id)"
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
Export-ModuleMember -Function Resolve-DependenciesFromAzureFeed
