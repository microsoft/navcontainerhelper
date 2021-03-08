<# 
 .Synopsis
  Function for resolving dependencies using an AzureFeed
 .Description
  Function for resolving dependencies using an AzureFeed
  To being able to resolve dependencies an artifact must be in the following format.
  The app id must be in the artifact name so apps will be identified correctly.
  The artifact can contain an .runtime.app file. If no app.json or .app file is present the .runtime.app fill be treated as a leaf in the tree.
  If an app.json is present dependencies will be take from that file.
  If no app.json but an .app file is present that will be extracted and used to find dependencies. 
#>
function Resolve-DependenciesFromAzureFeed {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $organization,
        [Parameter(Mandatory = $true)]
        [string] $feed,
        [Parameter(Mandatory = $true)]
        [string] $appsPath,
        [string] $outPath = (Join-Path $appsPath '.alpackages'),
        [int] $lvl = -1
    )
    $spaces = ''
    $lvl++

    For ($i=0; $i -le $lvl; $i++) {
        $spaces += '   '
    }

    # Create outPath if not exits 
    if (!(Test-Path $outPath)) {
        New-Item -Path $outPath -ItemType Directory -Force | Out-Null
    }

    # Search for app.jsons
    $apps = @(Get-ChildItem -Path (Join-Path $appsPath '/*/app.json'))
    if ($apps.Count -eq 0) {
        # Look for a single app.json in root
        try {
            $apps = @(Get-ChildItem -Path (Join-Path $appsPath '/app.json'))
        } catch {}
    }
    if ($apps.Count -eq 0) {
        # If no app.jsons found look for .app files.
        $apps = @(Get-ChildItem -Path (Join-Path $appsPath '*.app') -Exclude '*.runtime.app')
    }

    Write-Host "$($spaces)$($apps.Count) apps found";

    $apps | % {

        if($_.Name -eq "app.json") {
            Write-Host "$($spaces)$($_.DirectoryName | Split-Path -Leaf)"
        } else {
            Write-Host "$($spaces)$($_.Name)"
        }

        # Create temp folders
        $tempAppFolder = Join-Path ((Get-Item -Path $env:temp).FullName) ([Guid]::NewGuid().ToString())
        $tempAppDependenciesFolder = Join-Path $tempAppFolder 'dependencies'

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
        
        #Resolving dpendencies
        $appJson.dependencies | % {
            $tempAppDependencyFolder = Join-Path $tempAppDependenciesFolder $_.id
            New-Item -path $tempAppDependencyFolder -ItemType Directory -Force | Out-Null
            Write-Host "$($spaces)Downloading: $($_.id)"
            try {
                if( $(az artifacts universal download `
                    --organization $organization `
                    --feed $feed `
                    --name $_.id `
                    --version (AzureFeedWildcardVersion -appVersion $_.version) `
                    --path $tempAppDependencyFolder >$null 2>&1; $?)) {
                        Write-Host "$($spaces)Downloaded!"
                    }
            }
            catch {
                Write-Warning "$($spaces)Cannot find the package $($_.id)"
            }
            
            $dependency = @(Get-ChildItem -Path (Join-Path $tempAppDependencyFolder '*.app') -Exclude '*.runtime.app')
            if ($dependency.Count -eq 0) {
                $dependency = @(Get-ChildItem -Path (Join-Path $tempAppDependencyFolder '*.runtime.app'))
            }
            if ($dependency.Count -gt 0) {
                $dep = $dependency[0]
                if(!(Test-Path (Join-Path $outPath $dep.Name))) {
                    Copy-Item -Path $dep -Destination $outPath -Force

                    Write-Host "$($spaces)Copied to $($outPath)"

                    Resolve-DependenciesFromAzureFeed -organization $organization -feed $feed -outPath $outPath -appsPath $tempAppDependencyFolder -lvl $lvl
                } else {
                    Write-Host "$($spaces)$($dep.Name) exists"
                }
            } 
        }
        if ($appJson.dependencies.Count -eq 0) {
            Write-Host "$($spaces)No more dependencies."
        }
        Remove-Item -Path $tempAppFolder -Recurse -Force
    }

}
Export-ModuleMember -Function Resolve-DependenciesFromAzureFeed
