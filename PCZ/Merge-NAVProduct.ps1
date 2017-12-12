$dockerImageTag = "navdocker.azurecr.io/dynamics-nav:%0-na" #"microsoft/dynamics-nav:%0-na"

function Merge-NAVProduct (
    [Parameter(Mandatory=$true)]
    [String] $NAVBuild,
    [Parameter(Mandatory=$true)]
    [String] $BaseObjectsPath,
    [Parameter(Mandatory=$true)]
    [String] $ModifiedObjectsPath,
    [Parameter(Mandatory=$true)]
    [String] $NAVProductObjects,
    [Parameter(Mandatory=$true)]
    [String] $ResultPath,
    [Parameter(Mandatory=$true)]
    [String] $LicenseFile,
    [Parameter(Mandatory=$true)]
    [String] $VersionListFilter,
    [Parameter(Mandatory=$true)]
    [String] $NewVersionList
  )
{
    $BuildScript = "Docker-Merge.ps1"
    $SetupScript = "Docker-Setup.ps1"

    if (!(Test-Path $ModifiedObjectsPath))
    {
        Throw "Modified Objects Path '$ModifiedObjectsPath' doesn't exist"
    }
    if (!(Test-Path $BaseObjectsPath))
    {
        Throw "Base Objects Path '$BaseObjectsPath' doesn't exist"
    }
    if (!(Test-Path $NAVProductObjects))
    {
        Throw "NAV Product Objects Path '$NAVProductObjects' doesn't exist"
    }
    if (!(Test-Path $ResultPath))
    {
        New-Item -Path $ResultPath -ItemType Directory | Out-Null
    }
    if (!(Test-Path $LicenseFile))
    {
        Throw "License file '$LicenseFile' doesn't exist"
    }
    if (!(Get-Item $LicenseFile) -is [System.IO.FileInfo])
    {
        Throw "License file '$LicenseFile' doesn't exist"
    }

    Write-Host "Starting product merge process"
    Write-Host "Creating Directories"

    $TempPath = Join-Path $ResultPath "Temp"
    $BuildPath = Join-Path $PSScriptRoot $BuildScript
    $TempSource = Join-Path $TempPath "Source"
    $TempLog = Join-Path $TempPath "Logs"
    $TempMergeSource = Join-Path $TempPath "MergeSource"
    $TempMergeModified = Join-Path $TempPath "MergeModified"
    $TempMergeTarget = Join-Path $TempPath "MergeTarget"
    $TempMergeResult = Join-Path $TempPath "MergeResult"
    $TempResults = Join-Path $TempPath "Results"
    $TempBuild = Join-Path $TempPath "AdditionalSetup.ps1"
    $TempSetup = Join-Path $TempPath "SetupVariables.ps1"
    $TempLicense = Join-Path $TempPath "License.flf"

    New-Item -ItemType Directory -Path $TempSource | Out-Null
    New-Item -ItemType Directory -Path $TempLog | Out-Null
    New-Item -ItemType Directory -Path $TempMergeModified | Out-Null
    New-Item -ItemType Directory -Path $TempMergeSource | Out-Null
    New-Item -ItemType Directory -Path $TempMergeTarget | Out-Null
    New-Item -ItemType Directory -Path $TempMergeResult | Out-Null
    New-Item -ItemType Directory -Path $TempResults | Out-Null
    New-Item -ItemType Directory -Path (Join-Path -Path $TempResults "Objects") | Out-Null
    
    # copy objects over to specific folder
    Write-Host "Copying source files"
    if ((Get-Item $ModifiedObjectsPath) -is [System.IO.DirectoryInfo])
    {
        Copy-Item -Path (Join-Path $ModifiedObjectsPath "*.*") -Destination $TempSource -Recurse -Force
    }
    else
    {
        Copy-Item -Path $ModifiedObjectsPath -Destination $TempSource -Recurse -Force
    }
    
    Write-Host "Copying product files"
    Copy-Item -Path (Join-Path $NAVProductObjects "*.TXT") -Destination $TempMergeModified -Recurse -Force
    Copy-Item -Path (Join-Path $BaseObjectsPath "*.TXT") -Destination $TempMergeSource -Recurse -Force

    Write-Host "Copying processing files"
    Copy-Item -Path $BuildPath -Destination $TempBuild -Force
    Copy-Item -Path $SetupScript -Destination $TempSetup -Force
    Copy-Item -Path $LicenseFile -Destination $TempLicense -Force

    Add-Content -Value "`$ResultFilter=`"Version List=$VersionListFilter`"" -Path $TempSetup
    Add-Content -Value "`$NewVersionList=`"$NewVersionList`"" -Path $TempSetup
         
    Write-Host "Starting Merge Process on Docker"
    Start-NAVDocker -TempPath $TempPath -Version $NAVBuild

    Write-Host "Copying object files to result"
    if (Test-Path $TempMergeResult)
    {
        Copy-Item -Path (Join-Path $TempMergeResult "*.*") $ResultPath -Recurse -Force
        Write-Error "Merge resulted in conflicts. The results will be in the Results path for manual processing."
    }
    else
    {
        Copy-Item -Path (Join-Path $TempResults "*.*") $ResultPath -Force
        Write-Host "Merge Succeeded. The results are in the Results path."
    }

    Write-Host "Cleaning up"
    Stop-NAVDocker

    Remove-Item -Path $TempPath -Recurse -Force

    Read-Host "Press any key..."
}

function Start-NAVDocker($TempPath, $Version)
{
    $build = $dockerImageTag.Replace("%0", $Version)

    $runningDockers = docker ps -f name=productmerge -a -q
    ForEach ($docker in $runningDockers)
    {
        docker stop $docker | Out-Null
        docker rm $docker | Out-Null
    }
    docker pull $build 
    docker run -m 4g --name productmerge --hostname productmerge --volume ($TempPath + ":" + "C:\Run\My") --env username=sa --env password=Password1 $build

    if ((docker ps -f name=productmerge -q) -eq $null)
    {
        Throw "Error starting docker image"
    }
}

function Stop-NAVDocker
{
    docker stop productmerge
    docker rm productmerge
}

function New-TemporaryDirectory 
{
    $parent = [System.IO.Path]::GetTempPath()
    [String] $name = [System.Guid]::NewGuid()
    $item = New-Item -ItemType Directory -Path (Join-Path $parent $name)

    return (Join-Path $parent $name)
}