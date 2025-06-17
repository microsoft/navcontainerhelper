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
 .Parameter databaseBackupPath
  Path to database backup to use in place of Cronus backup. By default database backup from manifest is used. This parameter can be used to override this and use your custom backup.
 .Parameter registryCredential
  Credentials for the registry for baseImage if you are using a private registry (incl. bcinsider)
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
 .Parameter runSandboxAsOnPrem
  This parameter will attempt to run sandbox artifacts as onprem (will only work with version 18 and later)
 .Parameter populateBuildFolder
  Adding this parameter causes the function to populate this folder with DOCKERFILE and other files needed to build the image instead of building the image
 .Parameter additionalLabels
  additionalLabels can contain an array of additional labels for the image
#>
function New-BcImage {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $artifactUrl,
        [string] $imageName = "myimage",
        [string] $baseImage = "",
        [string] $databaseBackupPath = "",
        [PSCredential] $registryCredential,
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
        [switch] $runSandboxAsOnPrem,
        [string] $populateBuildFolder = "",
        [string[]] $additionalLabels = @(),
        $allImages
    )


function RoboCopyFiles {
    Param(
        [string] $source,
        [string] $destination,
        [string] $files = "*",
        [switch] $e
    )

    Write-Host $source
    if ($e) {
        RoboCopy "$source" "$destination" "$files" /e /NFL /NDL /NJH /NJS /nc /ns /np /mt /z /nooffload | Out-Null
        Get-ChildItem -Path $source -Filter $files -Recurse | ForEach-Object {
            $destPath = Join-Path $destination $_.FullName.Substring($source.Length)
            while (!(Test-Path $destPath)) {
                Write-Host "Waiting for $destPath to be available"
                Start-Sleep -Seconds 1
            }
        }
    }
    else {
        RoboCopy "$source" "$destination" "$files" /NFL /NDL /NJH /NJS /nc /ns /np /mt /z /nooffload | Out-Null
        Get-ChildItem -Path $source -Filter $files | ForEach-Object {
            $destPath = Join-Path $destination $_.FullName.Substring($source.Length)
            while (!(Test-Path $destPath)) {
                Write-Host "Waiting for $destPath to be available"
                Start-Sleep -Seconds 1
            }
        }
    }
}

$telemetryScope = InitTelemetryScope `
                    -name $MyInvocation.InvocationName `
                    -parameterValues $PSBoundParameters `
                    -includeParameters @("containerName","artifactUrl","isolation","imageName","baseImage","registryCredential","multitenant","filesOnly")
try {

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
    $isServerHost = $os.ProductType -eq 3

    if ("$baseImage" -eq "") {
        if ("$bestGenericImageName" -eq "") {
            $bestGenericImageName = Get-BestGenericImageName -filesOnly:$filesOnly
            Write-Host "WARNING: Unable to find matching generic image for your host OS. Using $bestGenericImageName"
        }
        $baseImage = $bestGenericImageName
    }

    if ($os.BuildNumber -eq 26100) {
        if ($isServerHost) {
            $hostOs = "ltsc2025"
        }
        else {
            $hostOs = "24H2"
        }
    }
    elseif ($os.BuildNumber -eq 22631) {
        $hostOs = "23H2"
    }
    elseif ($os.BuildNumber -eq 22621) {
        $hostOs = "22H2"
    }
    elseif ($os.BuildNumber -eq 22000) { 
        $hostOs = "21H2"
    }
    elseif ($os.BuildNumber -eq 20348) { 
        $hostOs = "ltsc2022"
    }
    elseif ($os.BuildNumber -eq 19045) { 
        $hostOs = "22H2"
    }
    elseif ($os.BuildNumber -eq 19044) { 
        $hostOs = "21H2"
    }
    elseif ($os.BuildNumber -eq 19043) { 
        $hostOs = "21H1"
    }
    elseif ($os.BuildNumber -eq 19042) { 
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
    if (!$runSandboxAsOnPrem -and $appManifest.PSObject.Properties.name -eq "isBcSandbox") {
        if ($appManifest.isBcSandbox) {
            if (!($PSBoundParameters.ContainsKey('multitenant')) -and !$skipDatabase) {
                $multitenant = $bcContainerHelperConfig.sandboxContainersAreMultitenantByDefault
            }
        }
    }

    if ($appManifest.version -like "21.0.*" -and $licenseFile -eq "") {
        Write-Host "The CRONUS Demo License shipped in Version 21.0 artifacts doesn't contain sufficient rights to all Test Libraries objects. Patching the license file."
        $country = $appManifest.Country.ToLowerInvariant()
        if (@('at','au','be','ca','ch','cz','de','dk','es','fi','fr','gb','in','is','it','mx','nl','no','nz','ru','se','us') -contains $country) {
            $licenseFile = "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/prerequisites/21demolicense/$country/3048953.bclicense"
        }
        else {
            $licenseFile = "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/prerequisites/21demolicense/w1/3048953.bclicense"
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

    if ($populateBuildFolder -eq "") {
        $buildMutexName = "img-$imageName"
        $buildMutex = New-Object System.Threading.Mutex($false, $buildMutexName)
}
    try {
        try {
            if ($populateBuildFolder -eq "") {
                if (!$buildMutex.WaitOne(1000)) {
                    Write-Host "Waiting for other process building image $imageName"
                    $buildMutex.WaitOne() | Out-Null
                    Write-Host "Other process completed building"
                    $allImages = @()
                }
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
                    $labels = Get-BcContainerImageLabels -imageName $baseImage -registryCredential $registryCredential
            
                    $imageArtifactUrl = ($inspect.config.env | ? { $_ -like "artifactUrl=*" }).SubString(12).Split('?')[0]
                    if ((ReplaceCDN -sourceUrl $imageArtifactUrl -useBlobUrl) -ne (ReplaceCDN -sourceUrl $artifactUrl.Split('?')[0] -useBlobUrl)) {
                        Write-Host "Image $imageName was built with artifactUrl $imageArtifactUrl, should be $($artifactUrl.Split('?')[0])"
                        $forceRebuild = $true
                    }
                    if ($inspect.Config.Labels.version -ne $appManifest.Version) {
                        Write-Host "Image $imageName was built with version $($inspect.Config.Labels.version), should be $($appManifest.Version)"
                        $forceRebuild = $true
                    }
                    elseif ($inspect.Config.Labels.Country -ne $appManifest.Country) {
                        Write-Host "Image $imageName was built with country $($inspect.Config.Labels.country), should be $($appManifest.country)"
                        $forceRebuild = $true
                    }
                    elseif ($inspect.Config.Labels.osversion -ne $labels.osversion) {
                        Write-Host "Image $imageName was built for OS Version $($inspect.Config.Labels.osversion), should be $($labels.osversion)"
                        $forceRebuild = $true
                    }
                    elseif ($inspect.Config.Labels.tag -ne $labels.tag) {
                        Write-Host "Image $imageName has generic Tag $($inspect.Config.Labels.tag), should be $($labels.tag)"
                        $forceRebuild = $true
                    }
                   
                    if (($inspect.Config.Labels.PSObject.Properties.Name -eq "Multitenant") -and ($inspect.Config.Labels.Multitenant -eq "Y")) {
                        if (!$multitenant) {
                            Write-Host "Image $imageName was built multi tenant, should have been single tenant"
                            $forceRebuild = $true
                        }
                    }
                    else {
                        if ($multitenant) {
                            Write-Host "Image $imageName was built single tenant, should have been multi tenant"
                            $forceRebuild = $true
                        }
                    }
            
                    if (($inspect.Config.Labels.PSObject.Properties.Name -eq "SkipDatabase") -and ($inspect.Config.Labels.SkipDatabase -eq "Y")) {
                        if (!$skipdatabase) {
                            Write-Host "Image $imageName was built without a database, should have a database"
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
            
            if ($populateBuildFolder) {
                $genericTag = [Version]"1.0.2.15"
            }
            else {
                if ($baseImage -like 'mcr.microsoft.com/businesscentral:*') {
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
                $containerOs = GetContainerOs -containerOsVersion $containerOsVersion
                Write-Host "Container OS Version: $containerOsVersion ($containerOs)"
                Write-Host "Host OS Version: $hostOsVersion ($hostOs)"
            
                if (($hostOsVersion.Major -lt $containerOsversion.Major) -or 
                    ($hostOsVersion.Major -eq $containerOsversion.Major -and $hostOsVersion.Minor -lt $containerOsversion.Minor) -or 
                    ($hostOsVersion.Major -eq $containerOsversion.Major -and $hostOsVersion.Minor -eq $containerOsversion.Minor -and $hostOsVersion.Build -lt $containerOsversion.Build)) {
            
                    throw "The container operating system is newer than the host operating system, cannot use image"
                }

                $isolation = GetIsolationMode -hostOsVersion $hostOsVersion -containerOsVersion $containerOsVersion -useSSL $false -isolation $isolation
                Write-Host "Using $isolation isolation"
            }
            
            $downloadsPath = $bcContainerHelperConfig.bcartifactsCacheFolder
            if (!(Test-Path $downloadsPath)) {
                New-Item $downloadsPath -ItemType Directory | Out-Null
            }
        
            if ($populateBuildFolder) {
                $buildFolder = $populateBuildFolder
                if (Test-Path $buildFolder) {
                    throw "$populateBuildFolder already exists"
                }
                New-Item $buildFolder -ItemType Directory | Out-Null
            }
            else {
                do {
                    $buildFolder = Join-Path $bcContainerHelperConfig.bcartifactsCacheFolder ([System.IO.Path]::GetRandomFileName())
                }
                until (New-Item $buildFolder -ItemType Directory -ErrorAction SilentlyContinue)
            }
        
            try {
        
                $myFolder = Join-Path $buildFolder "my"
                new-Item -Path $myFolder -ItemType Directory | Out-Null

                $InstallDotNet = ""
                if ($genericTag -le [Version]"1.0.2.13" -and [Version]$appManifest.Version -ge [Version]"22.0.0.0") {
                    Write-Host "Patching SetupConfiguration.ps1 due to issue #2874"
                    $myscripts += @( "https://raw.githubusercontent.com/microsoft/nav-docker/main/generic/Run/210-new/SetupConfiguration.ps1" )
                    Write-Host "Patching prompt.ps1 due to issue #2891"
                    $myScripts += @( "https://raw.githubusercontent.com/microsoft/nav-docker/main/generic/Run/Prompt.ps1" )
                    $myScripts += @( "https://download.visualstudio.microsoft.com/download/pr/04389c24-12a9-4e0e-8498-31989f30bb22/141aef28265938153eefad0f2398a73b/dotnet-hosting-6.0.27-win.exe" )
                    Write-Host "Base image is generic image 1.0.2.13 or below, installing dotnet 6.0.27"
                    $InstallDotNet = 'RUN start-process -Wait -FilePath "c:\run\dotnet-hosting-6.0.27-win.exe" -ArgumentList /quiet'
                }

                if ($genericTag -le [Version]"1.0.2.14" -and [Version]$appManifest.Version -ge [Version]"24.0.0.0") {
                    $myScripts += @( "https://download.visualstudio.microsoft.com/download/pr/98ff0a08-a283-428f-8e54-19841d97154c/8c7d5f9600eadf264f04c82c813b7aab/dotnet-hosting-8.0.2-win.exe" )
                    $myScripts += @( "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi" )
                    Write-Host "Base image is generic image 1.0.2.14 or below, installing dotnet 8.0.2"
                    $InstallDotNet = 'RUN start-process -Wait -FilePath "c:\run\dotnet-hosting-8.0.2-win.exe" -ArgumentList /quiet ; start-process -Wait -FilePath c:\run\powershell-7.4.1-win-x64.msi -ArgumentList /quiet'
                }

                if ($genericTag -ge [Version]"1.0.2.15" -and [Version]$appManifest.Version -ge [Version]"15.0.0.0" -and [Version]$appManifest.Version -lt [Version]"19.0.0.0") {
                    $myScripts += @( "https://download.microsoft.com/download/6/F/B/6FB4F9D2-699B-4A40-A674-B7FF41E0E4D2/DotNetCore.1.0.7_1.1.4-WindowsHosting.exe" )
                    Write-Host "Base image is generic image 1.0.2.15 or higher, installing ASP.NET Core 1.1"
                    $InstallDotNet = 'RUN start-process -Wait -FilePath "c:\run\DotNetCore.1.0.7_1.1.4-WindowsHosting.exe" -ArgumentList /quiet'
                }

                if ($genericTag -eq [Version]"1.0.2.15" -and [Version]$appManifest.Version -ge [Version]"24.0.0.0") {
                    $myScripts += @( 'https://raw.githubusercontent.com/microsoft/nav-docker/4b8870e6c023c399d309e389bf32fde44fcb1871/generic/Run/240/navinstall.ps1' )
                    Write-Host "Patching installer from generic image 1.0.2.15"
                }

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
                    if ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
                        Write-Host "Using license file $($licenseFile.Split('?')[0])"
                        $ext = [System.IO.Path]::GetExtension($licenseFile.Split('?')[0])
                        $licenseFilePath = Join-Path $myFolder "license$ext"
                        Download-File -sourceUrl $licenseFile -destinationFile $licenseFilePath
                        if ((Get-Content $licenseFilePath -First 1) -ne "Microsoft Software License Information") {
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
                get-childitem -Path $myfolder | ForEach-Object { Write-Host "- $($_.Name)" }
        
                $isBcSandbox = "N"
                if (!$runSandboxAsOnPrem -and $appManifest.PSObject.Properties.name -eq "isBcSandbox") {
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
                RobocopyFiles -source "$platformArtifactPath" -destination "$navDvdPath" -e
        
                if (!$skipDatabase) {
                    $CommonData = "CommApp"
                    if ($appManifest.version -lt [Version]"27.0.33344.0")
                    {
                        $CommonData = "CommonAppData"
                    }

                    $dbPath = Join-Path $navDvdPath "SQLDemoDatabase\$CommonData\Microsoft\Microsoft Dynamics NAV\ver\Database"
                    New-Item $dbPath -ItemType Directory | Out-Null
                    if (($databaseBackupPath) -and (Test-Path $databaseBackupPath -PathType Leaf))
                    {
                        Write-Host "Using database backup from $databaseBackupPath"
                        $databasePath = $databaseBackupPath
                    }
                    Write-Host "Copying Database"
                    Copy-Item -path $databasePath -Destination $dbPath -Force
                    if ($licenseFilePath) {
                        Write-Host "Copying Licensefile"
                        Copy-Item -path $licenseFilePath -Destination "$dbPath\CRONUS.flf" -Force
                    }
                }
        
                "Installers", "ConfigurationPackages", "TestToolKit", "UpgradeToolKit", "Extensions", "Applications","Applications.*" | ForEach-Object {
                    $appSubFolder = Join-Path $appArtifactPath $_
                    if (Test-Path $appSubFolder -PathType Container) {
                        $appSubFolder = (Get-Item $appSubFolder).FullName
                        $name = [System.IO.Path]::GetFileName($appSubFolder)
                        $destFolder = Join-Path $navDvdPath $name
                        if (Test-Path $destFolder) {
                            Remove-Item -path $destFolder -Recurse -Force
                        }
                        Write-Host "Copying $name"
                        RoboCopyFiles -Source "$appSubFolder" -Destination "$destFolder" -e
                    }
                }
            
                if ($populateBuildFolder -eq "") {
                    docker images --format "{{.Repository}}:{{.Tag}}" | ForEach-Object { 
                        if ($_ -eq $imageName) 
                        {
                            docker rmi --no-prune $imageName -f | Out-Host
                        }
                    }
                }
        
                Write-Host $buildFolder
                
                $skipDatabaseLabel = ""
                if ($skipDatabase) {
                    $skipDatabaseLabel = "skipdatabase=""Y"" \`n      "
                }
        
                $multitenantLabel = ""
                $multitenantParameter = ""
                if ($multitenant) {
                    $multitenantLabel = "multitenant=""Y"" \`n      "
                    $multitenantParameter = " -multitenant"
                }
        
                $dockerFileAddFonts = ""
                if ($addFontsFromPath) {
                    $found = $false
                    $fontsFolder = Join-Path $buildFolder "Fonts"
                    New-Item $fontsFolder -ItemType Directory | Out-Null
                    $extensions = @(".fon", ".fnt", ".ttf", ".ttc", ".otf")
                    Get-ChildItem $addFontsFromPath -ErrorAction Ignore | ForEach-Object {
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
                        if (!($licenseFile) -and ($appManifest.version -lt [Version]"22.0.0.0")) {
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
    
                $additionalLabelsStr = ""
                $additionalLabels | ForEach-Object {
                    $additionalLabelsStr += "$_ \`n      "
                }
@"
FROM $baseimage

ENV DatabaseServer=localhost DatabaseInstance=SQLEXPRESS DatabaseName=CRONUS IsBcSandbox=$isBcSandbox artifactUrl=$artifactUrl filesOnly=$filesOnly

COPY my /run/
COPY NAVDVD /NAVDVD/
$DockerFileAddFonts
$InstallDotNet

RUN \Run\start.ps1 -installOnly$multitenantParameter$TestToolkitParameter

LABEL legal="http://go.microsoft.com/fwlink/?LinkId=837447" \
      created="$([DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm"))" \
      nav="$nav" \
      cu="$cu" \
      $($skipDatabaseLabel)$($multitenantLabel)$($additionalLabelsStr)country="$($appManifest.Country)" \
      version="$($appmanifest.Version)" \
      platform="$($appManifest.Platform)"
"@ | Set-Content (Join-Path $buildFolder "DOCKERFILE")

                if ($populateBuildFolder) {
                    Write-Host "$populateBuildFolder populated, skipping build of image"
                }
                else {
                    if (!(DockerDo -command build -parameters @("--isolation=$isolation", "--memory $memory", "--no-cache", "--tag $imageName") -imageName $buildFolder)) {
                        throw "Docker Build didn't indicate success"
                    }
    
                    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
                    Write-Host "Building image took $timespend seconds"
                }
            }
            finally {
                if ($populateBuildFolder -eq "") {
                    Remove-Item $buildFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    finally {
        if ($populateBuildFolder -eq "") {
            $buildMutex.ReleaseMutex()
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
Set-Alias -Name New-NavImage -Value New-BcImage
Export-ModuleMember -Function New-BcImage -Alias New-NavImage
