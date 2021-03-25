<# 
 .Synopsis
  Create or refresh NAV/BC image
 .Description
  Creates a new image based on artifacts and a base image
  The function returns the imagename of the image created
 .Parameter artifactUrl
  Url for application artifact to use
 .Parameter imageName
  Name of the image getting build. Default is myimage:<tag describing version>.
 .Parameter baseImage
  BaseImage to use. Default is using Get-BestGenericImage to get the best generic image to use.
 .Parameter isolation
  Isolation mode for the image build process (default is process if baseImage OS matches host OS)
 .Parameter memory
  Memory allocated for building image. 8G is default.
 .Parameter myScripts
  This allows you to specify a number of scripts you want to copy to the c:\run\my folder in the container (override functionality)
 .Parameter skipDatabase
  Adding this parameter creates an image without a database
 .Parameter filesOnly
  Include this switch to create a filesOnly container. A filesOnly container does not contain SQL Server, IIS or the ServiceTier, it only contains the files from BC in the same locations as a normal container.
  A FilesOnly container can be used to compile apps and it can be used as a proxy container for an online Business Central environment
 .Parameter multitenant
  Adding this parameter creates an image with multitenancy
 .Parameter addFontsFromPath
  Enumerate all fonts from this path or array of paths and install them in the container
#>
function New-BcImage {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $artifactUrl,
        [string] $imageName = "myimage",
        [string] $baseImage = "",
        [ValidateSet('','process','hyperv')]
        [string] $isolation = "",
        [string] $memory = "",
        $myScripts = @(),
        [switch] $skipDatabase,
        [switch] $multitenant,
        [switch] $filesOnly,
        [string[]] $addFontsFromPath = @(""),
        [string] $licenseFile = "",
        [switch] $includeTestToolkit,
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [switch] $includePerformanceToolkit,
        [switch] $skipIfImageAlreadyExists,
        $allImages
    )

    if ($memory -eq "") {
        $memory = "8G"
    }

    $imageName = $imageName.ToLowerInvariant()

    $myScripts | ForEach-Object {
        if ($_ -is [string]) {
            if ($_.StartsWith("https://", "OrdinalIgnoreCase") -or $_.StartsWith("http://", "OrdinalIgnoreCase")) {
            } elseif (!(Test-Path $_)) {
                throw "Script directory or file $_ does not exist"
            }
        } elseif ($_ -isnot [Hashtable]) {
            throw "Illegal value in myScripts"
        }
    }

    $os = (Get-CimInstance Win32_OperatingSystem)
    if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
        throw "Unknown Host Operating System"
    }
    $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
    
    $hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")
    $hostOs = "Unknown/Insider build"
    $bestGenericImageName = Get-BestGenericImageName -onlyMatchingBuilds -filesOnly:$filesOnly

    if ("$baseImage" -eq "") {
        if ("$bestGenericImageName" -eq "") {
            $bestGenericImageName = Get-BestGenericImageName -filesOnly:$filesOnly
            Write-Host "WARNING: Unable to find matching generic image for your host OS. Using $bestGenericImageName"
        }
        $baseImage = $bestGenericImageName
    }

    if ($os.BuildNumber -eq 19042) { 
        $hostOs = "20H2"
    }
    elseif ($os.BuildNumber -eq 19041) { 
        $hostOs = "2004"
    }
    elseif ($os.BuildNumber -eq 18363) { 
        $hostOs = "1909"
    }
    elseif ($os.BuildNumber -eq 18362) { 
        $hostOs = "1903"
    }
    elseif ($os.BuildNumber -eq 17763) { 
        $hostOs = "ltsc2019"
    }
    elseif ($os.BuildNumber -eq 17134) { 
        $hostOs = "1803"
    }
    elseif ($os.BuildNumber -eq 16299) { 
        $hostOs = "1709"
    }
    elseif ($os.BuildNumber -eq 15063) {
        $hostOs = "1703"
    }
    elseif ($os.BuildNumber -eq 14393) {
        $hostOs = "ltsc2016"
    }

    $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
    $appArtifactPath = $artifactPaths[0]
    $platformArtifactPath = $artifactPaths[1]

    $appManifestPath = Join-Path $appArtifactPath "manifest.json"
    $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
    if ($appManifest.PSObject.Properties.name -eq "isBcSandbox") {
        if ($appManifest.isBcSandbox) {
            if (!($PSBoundParameters.ContainsKey('multitenant')) -and !$skipDatabase) {
                $multitenant = $bcContainerHelperConfig.sandboxContainersAreMultitenantByDefault
            }
        }
    }

    $dbstr = ""
    $mtstr = ""
    if (!$imageName.Contains(':')) {
        $appUri = [Uri]::new($artifactUrl)
        $imageName += ":$($appUri.AbsolutePath.ToLowerInvariant().Replace('/','-').TrimStart('-'))"
        if ($filesOnly) {
            $imageName += "-filesonly"
            $dbstr = " with files only"
        }
        else {
            if ($skipDatabase) {
                $imageName += "-nodb"
                $dbstr = " without database"
    
            }
            if ($multitenant) {
                $imageName += "-mt"
                $mtstr = " multitenant"
            }
        }
    }

    $imageName

    $buildMutexName = "img-$imageName"
    $buildMutex = New-Object System.Threading.Mutex($false, $buildMutexName)
    try {
        try {
            if (!$buildMutex.WaitOne(1000)) {
                Write-Host "Waiting for other process building image $imageName"
                $buildMutex.WaitOne() | Out-Null
                Write-Host "Other process completed building"
                $allImages = @()
            }
        }
        catch [System.Threading.AbandonedMutexException] {
           Write-Host "Other process terminated abnormally"
        }

        $forceRebuild = $true
        if ($skipIfImageAlreadyExists) {
    
            if (-not ($allImages)) {
                Write-Host "Fetching all docker images"
                $allImages = @(docker images --format "{{.Repository}}:{{.Tag}}")
            }
    
            if ($allImages | Where-Object { $_ -eq $imageName }) {
                
                $forceRebuild = $false
    
                try {
                    Write-Host "Image $imageName already exists"
                    $inspect = docker inspect $imageName | ConvertFrom-Json
                    $labels = Get-BcContainerImageLabels -imageName $baseImage
            
                    $imageArtifactUrl = ($inspect.config.env | ? { $_ -like "artifactUrl=*" }).SubString(12).Split('?')[0]
                    if ("$imageArtifactUrl".ToLowerInvariant().Replace('.blob.core.windows.net/','.azureedge.net/') -ne "$($artifactUrl.Split('?')[0])".ToLowerInvariant().Replace('.blob.core.windows.net/','.azureedge.net/'))  {
                        Write-Host "Image $imageName was build with artifactUrl $imageArtifactUrl, should be $($artifactUrl.Split('?')[0])"
                        $forceRebuild = $true
                    }
                    if ($inspect.Config.Labels.version -ne $appManifest.Version) {
                        Write-Host "Image $imageName was build with version $($inspect.Config.Labels.version), should be $($appManifest.Version)"
                        $forceRebuild = $true
                    }
                    elseif ($inspect.Config.Labels.Country -ne $appManifest.Country) {
                        Write-Host "Image $imageName was build with version $($inspect.Config.Labels.version), should be $($appManifest.Version)"
                        $forceRebuild = $true
                    }
                    elseif ($inspect.Config.Labels.osversion -ne $labels.osversion) {
                        Write-Host "Image $imageName was build for OS Version $($inspect.Config.Labels.osversion), should be $($labels.osversion)"
                        $forceRebuild = $true
                    }
                    elseif ($inspect.Config.Labels.tag -ne $labels.tag) {
                        Write-Host "Image $imageName has generic Tag $($inspect.Config.Labels.tag), should be $($labels.tag)"
                        $forceRebuild = $true
                    }
                   
                    if (($inspect.Config.Labels.PSObject.Properties.Name -eq "Multitenant") -and ($inspect.Config.Labels.Multitenant -eq "Y")) {
                        if (!$multitenant) {
                            Write-Host "Image $imageName was build multi tenant, should have been single tenant"
                            $forceRebuild = $true
                        }
                    }
                    else {
                        if ($multitenant) {
                            Write-Host "Image $imageName was build single tenant, should have been multi tenant"
                            $forceRebuild = $true
                        }
                    }
            
                    if (($inspect.Config.Labels.PSObject.Properties.Name -eq "SkipDatabase") -and ($inspect.Config.Labels.SkipDatabase -eq "Y")) {
                        if (!$skipdatabase) {
                            Write-Host "Image $imageName was build without a database, should have a database"
                            $forceRebuild = $true
                        }
                    }
                    else {
                        # Do not rebuild if database is there, just don't use it
                    }
                }
                catch {
                    Write-Host "Exception $($_.ToString())"
                    $forceRebuild = $true
                }
            }
        }
    
        if ($forceRebuild) {
    
            Write-Host "Building$mtstr image $imageName based on $baseImage with $($artifactUrl.Split('?')[0])$dbstr"
            $startTime = [DateTime]::Now
            
            if ($baseImage -eq $bestGenericImageName) {
                Write-Host "Pulling latest image $baseImage"
                DockerDo -command pull -imageName $baseImage | Out-Null
            }
            else {
                $baseImageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq "$baseImage" }
                if (!($baseImageExists)) {
                    Write-Host "Pulling non-existing base image $baseImage"
                    DockerDo -command pull -imageName $baseImage | Out-Null
                }
            }
        
            $genericTag = [Version](Get-BcContainerGenericTag -containerOrImageName $baseImage)
            Write-Host "Generic Tag: $genericTag"
            if ($genericTag -lt [Version]"0.1.0.16") {
                throw "Generic tag must be at least 0.1.0.16. Cannot build image based on $genericTag"
            }
        
            $containerOsVersion = [Version](Get-BcContainerOsVersion -containerOrImageName $baseImage)
            if ("$containerOsVersion".StartsWith('10.0.14393.')) {
                $containerOs = "ltsc2016"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.15063.')) {
                $containerOs = "1703"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.16299.')) {
                $containerOs = "1709"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.17134.')) {
                $containerOs = "1803"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.17763.')) {
                $containerOs = "ltsc2019"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.18362.')) {
                $containerOs = "1903"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.18363.')) {
                $containerOs = "1909"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.19041.')) {
                $containerOs = "2004"
            }
            elseif ("$containerOsVersion".StartsWith('10.0.19042.')) {
                $containerOs = "20H2"
            }
            else {
                $containerOs = "unknown"
            }
            Write-Host "Container OS Version: $containerOsVersion ($containerOs)"
            Write-Host "Host OS Version: $hostOsVersion ($hostOs)"
        
            if (($hostOsVersion.Major -lt $containerOsversion.Major) -or 
                ($hostOsVersion.Major -eq $containerOsversion.Major -and $hostOsVersion.Minor -lt $containerOsversion.Minor) -or 
                ($hostOsVersion.Major -eq $containerOsversion.Major -and $hostOsVersion.Minor -eq $containerOsversion.Minor -and $hostOsVersion.Build -lt $containerOsversion.Build)) {
        
                throw "The container operating system is newer than the host operating system, cannot use image"
            
            }
        
            if ($hostOsVersion -eq $containerOsVersion) {
                if ($isolation -eq "") { 
                    $isolation = "process"
                }
            }
            else {
                if ($isolation -eq "") {
                    if ($isAdministrator) {
                        if (Get-HypervState -ne "Disabled") {
                            $isolation = "hyperv"
                        }
                        else {
                            $isolation = "process"
                            Write-Host "WARNING: Host OS and Base Image Container OS doesn't match and Hyper-V is not installed. If you encounter issues, you could try to install Hyper-V."
                        }
                    }
                    else {
                        $isolation = "hyperv"
                        Write-Host "WARNING: Host OS and Base Image Container OS doesn't match, defaulting to hyperv. If you do not have Hyper-V installed or you encounter issues, you could try to specify -isolation process"
                    }
        
                }
                elseif ($isolation -eq "process") {
                    Write-Host "WARNING: Host OS and Base Image Container OS doesn't match and process isolation is specified. If you encounter issues, you could try to specify -isolation hyperv"
                }
            }
            Write-Host "Using $isolation isolation"
        
            $downloadsPath = (Get-ContainerHelperConfig).bcartifactsCacheFolder
            if (!(Test-Path $downloadsPath)) {
                New-Item $downloadsPath -ItemType Directory | Out-Null
            }
        
            do {
                $buildFolder = Join-Path (Get-ContainerHelperConfig).bcartifactsCacheFolder ([System.IO.Path]::GetRandomFileName())
            }
            until (New-Item $buildFolder -ItemType Directory -ErrorAction SilentlyContinue)
        
            try {
        
                $myFolder = Join-Path $buildFolder "my"
                new-Item -Path $myFolder -ItemType Directory | Out-Null
            
                $myScripts | ForEach-Object {
                    if ($_ -is [string]) {
                        if ($_.StartsWith("https://", "OrdinalIgnoreCase") -or $_.StartsWith("http://", "OrdinalIgnoreCase")) {
                            $uri = [System.Uri]::new($_)
                            $filename = [System.Uri]::UnescapeDataString($uri.Segments[$uri.Segments.Count-1])
                            $destinationFile = Join-Path $myFolder $filename
                            Download-File -sourceUrl $_ -destinationFile $destinationFile
                            if ($destinationFile.EndsWith(".zip", "OrdinalIgnoreCase")) {
                                Write-Host "Extracting .zip file " -NoNewline
                                Expand-7zipArchive -Path $destinationFile -DestinationPath $myFolder
                                Remove-Item -Path $destinationFile -Force
                            }
                        } elseif (Test-Path $_ -PathType Container) {
                            Copy-Item -Path "$_\*" -Destination $myFolder -Recurse -Force
                        } else {
                            if ($_.EndsWith(".zip", "OrdinalIgnoreCase")) {
                                Write-Host "Extracting .zip file " -NoNewline
                                Expand-7zipArchive -Path $_ -DestinationPath $myFolder
                            } else {
                                Copy-Item -Path $_ -Destination $myFolder -Force
                            }
                        }
                    } else {
                        $hashtable = $_
                        $hashtable.Keys | ForEach-Object {
                            Set-Content -Path (Join-Path $myFolder $_) -Value $hashtable[$_]
                        }
                    }
                }
        
                $licenseFilePath = ""
                if ($licenseFile) {
                    $licenseFilePath = Join-Path $myFolder "license.flf"
                    if ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
                        Write-Host "Using license file $licenseFile"
                        Download-File -sourceUrl $licenseFile -destinationFile $licenseFilePath
                        $bytes = [System.IO.File]::ReadAllBytes($licenseFilePath)
                        $text = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 100)
                        if (!($text.StartsWith("Microsoft Software License Information"))) {
                            Remove-Item -Path $licenseFilePath -Force
                            throw "Specified license file Uri isn't a direct download Uri"
                        }
                    }
                    else {
                        Write-Host "Using license file $licenseFile"
                        $licenseFilePath = $licenseFile
                    }
                }
        
                Write-Host "Files in $($myfolder):"
                get-childitem -Path $myfolder | % { Write-Host "- $($_.Name)" }
        
                $isBcSandbox = "N"
                if ($appManifest.PSObject.Properties.name -eq "isBcSandbox") {
                    if ($appManifest.isBcSandbox) {
                        $IsBcSandbox = "Y"
                    }
                }
        
                if (!$skipDatabase){
                    $database = $appManifest.database
                    $databasePath = Join-Path $appArtifactPath $database
                    if ($licenseFile -eq "") {
                        if ($appManifest.PSObject.Properties.name -eq "licenseFile") {
                            $licenseFilePath = $appManifest.licenseFile
                            if ($licenseFilePath) {
                                $licenseFilePath = Join-Path $appArtifactPath $licenseFilePath
                            }
                        }
                    }
                }
        
                $nav = ""
                if ($appManifest.PSObject.Properties.name -eq "Nav") {
                    $nav = $appManifest.Nav
                }
                $cu = ""
                if ($appManifest.PSObject.Properties.name -eq "Cu") {
                    $cu = $appManifest.Cu
                }
            
                $navDvdPath = Join-Path $buildFolder "NAVDVD"
                New-Item $navDvdPath -ItemType Directory | Out-Null
        
                Write-Host "Copying Platform Artifacts"
                Robocopy "$platformArtifactPath" "$navDvdPath" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        
                if (!$skipDatabase) {
                    $dbPath = Join-Path $navDvdPath "SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\ver\Database"
                    New-Item $dbPath -ItemType Directory | Out-Null
                    Write-Host "Copying Database"
                    Copy-Item -path $databasePath -Destination $dbPath -Force
                    if ($licenseFilePath) {
                        Write-Host "Copying Licensefile"
                        Copy-Item -path $licenseFilePath -Destination "$dbPath\CRONUS.flf" -Force
                    }
                }
        
                "Installers", "ConfigurationPackages", "TestToolKit", "UpgradeToolKit", "Extensions", "Applications","Applications.*" | % {
                    $appSubFolder = Join-Path $appArtifactPath $_
                    if (Test-Path $appSubFolder -PathType Container) {
                        $appSubFolder = (Get-Item $appSubFolder).FullName
                        $name = [System.IO.Path]::GetFileName($appSubFolder)
                        $destFolder = Join-Path $navDvdPath $name
                        if (Test-Path $destFolder) {
                            Remove-Item -path $destFolder -Recurse -Force
                        }
                        Write-Host "Copying $name"
                        RoboCopy "$appSubFolder" "$destFolder" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
                    }
                }
            
                docker images --format "{{.Repository}}:{{.Tag}}" | % { 
                    if ($_ -eq $imageName) 
                    {
                        docker rmi --no-prune $imageName -f | Out-Host
                    }
                }
        
                Write-Host $buildFolder
                
                $skipDatabaseLabel = ""
                if ($skipDatabase) {
                    $skipDatabaseLabel = "skipdatabase=""Y"" \`n"
                }
        
                $multitenantLabel = ""
                $multitenantParameter = ""
                if ($multitenant) {
                    $multitenantLabel = "multitenant=""Y"" \`n"
                    $multitenantParameter = " -multitenant"
                }
        
                $dockerFileAddFonts = ""
                if ($addFontsFromPath) {
                    $found = $false
                    $fontsFolder = Join-Path $buildFolder "Fonts"
                    New-Item $fontsFolder -ItemType Directory | Out-Null
                    $extensions = @(".fon", ".fnt", ".ttf", ".ttc", ".otf")
                    Get-ChildItem $addFontsFromPath -ErrorAction Ignore | % {
                        if ($extensions.Contains($_.Extension.ToLowerInvariant())) {
                            Copy-Item -Path $_.FullName -Destination $fontsFolder
                            $found = $true
                        }
                    }
                    if ($found) {
                        Write-Host "Adding fonts"
                        Copy-Item -Path (Join-Path $PSScriptRoot "..\AddFonts.ps1") -Destination $fontsFolder
                        $dockerFileAddFonts = "COPY Fonts /Fonts/`nRUN . C:\Fonts\AddFonts.ps1`n"
                    }
                }
        
                $TestToolkitParameter = ""
                if ($genericTag -ge [Version]"0.1.0.18") {
                    if ($includeTestToolkit) {
                        if (!($licenseFile)) {
                            Write-Host "Cannot include TestToolkit without a licensefile, please specify licensefile"
                        }
                        $TestToolkitParameter = " -includeTestToolkit"
                        if ($includeTestLibrariesOnly) {
                            $TestToolkitParameter += " -includeTestLibrariesOnly"
                        }
                        elseif ($includeTestFrameworkOnly) {
                            $TestToolkitParameter += " -includeTestFrameworkOnly"
                        }
                    }
                }
                if ($genericTag -ge [Version]"0.1.0.21") {
                    if ($includeTestToolkit) {
                        if ($includePerformanceToolkit) {
                            $TestToolkitParameter += " -includePerformanceToolkit"
                        }
                    }
                }
    
@"
FROM $baseimage

ENV DatabaseServer=localhost DatabaseInstance=SQLEXPRESS DatabaseName=CRONUS IsBcSandbox=$isBcSandbox artifactUrl=$artifactUrl filesOnly=$filesOnly

COPY my /run/
COPY NAVDVD /NAVDVD/
$DockerFileAddFonts

RUN \Run\start.ps1 -installOnly$multitenantParameter$TestToolkitParameter

LABEL legal="http://go.microsoft.com/fwlink/?LinkId=837447" \
      created="$([DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm"))" \
      nav="$nav" \
      cu="$cu" \
      $($skipDatabaseLabel)$($multitenantLabel)country="$($appManifest.Country)" \
      version="$($appmanifest.Version)" \
      platform="$($appManifest.Platform)"
"@ | Set-Content (Join-Path $buildFolder "DOCKERFILE")

docker build --isolation=$isolation --memory $memory --tag $imageName $buildFolder | Out-Host

                $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
                Write-Host "Building image took $timespend seconds"
    
            }
            finally {
                Remove-Item $buildFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    finally {
        $buildMutex.ReleaseMutex()
    }
}
Set-Alias -Name New-NavImage -Value New-BcImage
Export-ModuleMember -Function New-BcImage -Alias New-NavImage
