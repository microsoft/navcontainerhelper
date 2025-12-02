<# 
 .Synopsis
  Extract the content of an App File to a Folder
 .Description
 .Parameter AppFilename
  Path of the application file
 .Parameter AppFolder
  Path of the folder in which the application File will be unpacked. If this folder exists, the content will be deleted. Default is $appFile.source.
 .Parameter GenerateAppJson
  Add this switch to generate an sample app.json file in the AppFolder, containing the manifest properties.
 .Parameter ExcludeRuntimeProperty
  Add this switch to remove the runtime version from the app.json 
 .Parameter LatestSupportedRuntimeVersion
  Add a version number to fail if the runtime version is higher than this version number
 .Parameter OpenFolder
  Add this parameter to open the destination folder in explorer
 .Example
  Extract-AppFileToFolder -appFilename c:\temp\baseapp.app
#>
function Extract-AppFileToFolder {
    Param (
        [string] $appFilename,
        [string] $appFolder = "",
        [switch] $generateAppJson,
        [switch] $excludeRuntimeProperty,
        [string] $latestSupportedRuntimeVersion,
        [switch] $openFolder
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Set-StrictMode -Off
    if ($appFolder -eq "") {
        if ($openFolder) {
            $generateAppJson = $true
            $appFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        }
        else {
            $appFolder = "$($appFilename).source"
        }
    }

    if ("$appFolder" -eq "($bcContainerHelperConfig.hostHelperFolder)" -or "$appFolder" -eq "$($bcContainerHelperConfig.hostHelperFolder)\") {
        throw "The folder specified in ObjectsFolder will be erased, you cannot specify $($bcContainerHelperConfig.hostHelperFolder)"
    }

    if (!(Test-Path $appFileName)) {
        throw "Unable to find $appFileName"
    }
    $appFileName = (Get-Item $appFileName).FullName

    Write-Host "Extracting $appFilename"    
    if (Test-Path $appFolder -PathType Container) {
        Get-ChildItem -Path $appFolder -Include * | Remove-Item -Recurse -Force
    } else {
        New-Item -Path $appFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
    }
   

    try {
        $filestream      = [System.IO.File]::OpenRead($appFileName)
        $binaryReader    = [System.IO.BinaryReader]::new($filestream)
        $magicNumber1    = $binaryReader.ReadUInt32()
        $metadataSize    = $binaryReader.ReadUInt32()
        $metadataVersion = $binaryReader.ReadUInt32()
        $packageId       = [Guid]::new($binaryReader.ReadBytes(16))
        $contentLength   = $binaryReader.ReadInt64()
        $magicNumber2    = $binaryReader.ReadUInt32()
        
        if ($magicNumber1 -ne 0x5856414E -or 
            $magicNumber2 -ne 0x5856414E -or 
            $metadataVersion -gt 2 -or
            $filestream.Position + $contentLength -gt $filestream.Length)
        {
            throw "Unsupported package format"
        }
    
        Add-Type -Assembly System.IO.Compression
        Add-Type -Assembly System.IO.Compression.FileSystem
        $content = $binaryReader.ReadBytes($contentLength)
        if ([bitConverter]::ToInt64($content,0) -eq 72057595132988974) {
            throw "You cannot extract a runtime package"
        }
        $memoryStream = [System.IO.MemoryStream]::new($content)
        $zipArchive = [System.IO.Compression.ZipArchive]::new($memoryStream, [System.IO.Compression.ZipArchiveMode]::Read)
        $prevdir = ""

        # If the app file is a ready-to-run app, it has a readytorunappmanifest.json file inside the archive
        $readyToRunAppManifest = $zipArchive.Entries | Where-Object { $_.FullName -eq "readytorunappmanifest.json" }
        if ($readyToRunAppManifest) {
            # Create a temporary folder to extract the ready-to-run app manifest
            $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            New-Item -Path $tmpFolder -ItemType Directory -Force | Out-Null

            # Extract the ready-to-run app manifest and get the embedded app file name
            $fullname = Join-Path $tmpFolder "readytorunappmanifest.json"
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($readyToRunAppManifest, $fullname)
            $embeddedAppFileName = (Get-Content -Path $fullname -Raw | ConvertFrom-Json).EmbeddedAppFileName
            $embeddedAppFile = $zipArchive.Entries | Where-Object { $_.FullName -eq $embeddedAppFileName }
            if (-not $embeddedAppFile) {
                throw "Unable to find embedded app file '$embeddedAppFile' in the ready-to-run app."
            }

            # Create a temporary folder to extract the app file to
            $fullname = Join-Path $tmpFolder ([Uri]::UnescapeDataString($embeddedAppFile.FullName))
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($embeddedAppFile, $fullname)

            # Close stream and binary reader before recursive call
            $binaryReader.Close()
            $filestream.Close()
            $memoryStream.Close()

            try {
                # Call the Extract-AppFileToFolder function again to extract the content of the app file
                Extract-AppFileToFolder -appFilename $fullname -appFolder $appFolder -generateAppJson:$generateAppJson -excludeRuntimeProperty:$excludeRuntimeProperty -latestSupportedRuntimeVersion:$latestSupportedRuntimeVersion -openFolder:$openFolder
            } finally {
                # Clean up the temporary folder
                Remove-Item $tmpFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
            return
        }

        $zipArchive.Entries | ForEach-Object {
            $fullname = Join-Path $appFolder ([Uri]::UnescapeDataString($_.FullName))
            $dir = [System.IO.Path]::GetDirectoryName($fullname)
            if ($dir -ne $prevdir) {
                if (-not (Test-Path $dir -PathType Container)) {
                    New-Item -Path $dir -ItemType Directory | Out-Null
                }
            }
            $prevdir = $dir
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $fullname)
        }
    }
    finally {
        $binaryReader.Close()
        $filestream.Close()
    }

    "/addin/src/", "/perm/", "/entit/", "/serv/", "/tabledata/", "/replay/", "/migration/", "/layout/" | ForEach-Object {
        $folder = Join-Path $appFolder $_
        if (Test-Path $folder) {
            @(Get-ChildItem $folder) | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $appFolder -Recurse -Force
                Remove-Item -Path $_.FullName -Recurse -Force
            }
        }
    }

    if ($generateAppJson) {
        $manifest = [xml](Get-Content -path (Join-Path $appFolder "NavxManifest.xml") -Encoding UTF8)
        $runtimeStr = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Runtime" } | ForEach-Object { $_.Value } )"
        if ($runtimeStr) {
            $runtime = [System.Version]$runtimeStr
        }
        else {
            $runtime = [System.Version]"9.2"
        }

        $application = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Application" } | ForEach-Object { $_.Value } )"
        $appJson = [ordered]@{
            "id" = $manifest.Package.App.Id
            "name" = $manifest.Package.App.Name
            "publisher" = $manifest.Package.App.Publisher
            "version" = $manifest.Package.App.Version
            "brief" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Brief" } | ForEach-Object { $_.Value } )"
            "description" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Description" } | ForEach-Object { $_.Value } )"
            "platform" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Platform" } | ForEach-Object { $_.Value } )"
        }
        if ($application) {
            $appJson += @{
                "application" = $application
            }
        }
        if ($latestSupportedRuntimeVersion -and $runtimeStr) {
            Write-Host "App Runtime Version is '$runtimeStr'"
            if ($runtime -gt [System.Version]$latestSupportedRuntimeVersion) {
                throw "App is using runtime version $runtimeStr, latest supported runtime version is $latestSupportedRuntimeVersion."
            }
        }
        if ($excludeRuntimeProperty.IsPresent) {
            Write-Host "Excluding Runtime Version from app.json"
        }
        else {
            $appJson += @{
                "runtime" = "$($runtime.Major).$($runtime.Minor)"
            }
        }
        $appJson += [ordered]@{
            "logo" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Logo" } | ForEach-Object { $_.Value } )".TrimStart('/')
            "url" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Url" } | ForEach-Object { $_.Value } )"
            "EULA" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "EULA" } | ForEach-Object { $_.Value } )"
            "privacyStatement" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "PrivacyStatement" } | ForEach-Object { $_.Value } )"
            "help" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Help" } | ForEach-Object { $_.Value } )"
            "target" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "target" } | ForEach-Object { $_.Value } )"
            "screenshots" = @()
            "dependencies" = @()
            "idRanges" = @()
            "features" = @()
        }

        if ($runtime -lt [System.Version]"8.0")  {
            $appJson += @{
                "showMyCode" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "ShowMyCode" } | ForEach-Object { $_.Value } )" -eq "True"
            }
        }
        else {
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "ResourceExposurePolicy" } | ForEach-Object { 
                $resExp = [ordered]@{}
                "allowDebugging", "allowDownloadingSource", "includeSourceInSymbolFile","applyToDevExtension" | ForEach-Object {
                    $prop = $_
                    if ($manifest.Package.ResourceExposurePolicy.Attributes | Where-Object { $_.name -eq $prop } | ForEach-Object { $_.Value -eq "true" }) {
                        $resExp += @{
                            "$prop" = $true
                        }
                    }
                }
                $appJson += @{ "resourceExposurePolicy" = $resExp }
            }
        }
        if ($runtime -ge [System.Version]"12.0")  {
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Source" } | ForEach-Object { 
                $node = $_
                $ht = [ordered]@{}
                "repositoryUrl", "commit" | ForEach-Object {
                    $prop = $_
                    if ($node) {
                        $node.Attributes | Where-Object { $_.name -eq $prop } | ForEach-Object {
                            $ht += @{
                                "$prop" = $_.Value.Trim('"')
                            }
                        }
                    }
                }
                $appJson += @{ "source" = $ht }
            }
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Build" } | ForEach-Object { 
                $node = $_
                $ht = [ordered]@{}
                "by", "url" | ForEach-Object {
                    $prop = $_
                    if ($node) {
                        $node.Attributes | Where-Object { $_.name -eq $prop } | ForEach-Object {
                            $ht += @{
                                "$prop" = $_.Value.Trim('"')
                            }
                        }
                    }
                }
                $appJson += @{ "build" = $ht }
            }
        }
        if ($runtime -ge [System.Version]"5.0")  {
            $appInsightsKey = $manifest.Package.App.Attributes | Where-Object { $_.name -eq "applicationInsightsKey" } | ForEach-Object { $_.Value } 
            if ($appInsightsKey) {
                $appJson += @{
                    "applicationInsightsKey" = "$appInsightsKey"
                }
            }
            elseif ($runtime -ge [System.Version]"7.2")  {
                $appInsightsConnectionString = $manifest.Package.App.Attributes | Where-Object { $_.name -eq "applicationInsightsConnectionString" } | ForEach-Object { $_.Value } 
                if ($appInsightsConnectionString) {
                    $appJson += @{
                        "applicationInsightsConnectionString" = "$appInsightsConnectionString"
                    }
                }
            }
        }
        $contextSensitiveHelpUrl = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "contextSensitiveHelpUrl" } | ForEach-Object { $_.Value } )"
        if ($contextSensitiveHelpUrl) {
            $appJson += @{
                "contextSensitiveHelpUrl" = $contextSensitiveHelpUrl
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Dependencies" } | ForEach-Object { 
            $_.GetEnumerator() | ForEach-Object {
                if ($runtime -gt [System.Version]"4.1") {
                    $propname = "id"
                }
                else {
                    $propname = "appId"
                }
                $appJson.dependencies += [ordered]@{
                    "$propname" = $_.Id
                    "publisher" = $_.publisher
                    "name" = $_.name
                    "version" = $_.minVersion
                }
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "IdRanges" } | ForEach-Object { 
            $_.GetEnumerator() | ForEach-Object {
                $appJson.idRanges += [ordered]@{
                    "from" = [Int]::Parse($_.MinObjectId)
                    "to" = [Int]::Parse($_.MaxObjectId)
                }
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Features" } | ForEach-Object { 
            $_.GetEnumerator() | ForEach-Object {
                $feature = $_.'#text'
                'ExcludeGeneratedTranslations','GenerateCaptions','GenerateLockedTranslations','NoImplicitWith','TranslationFile' | ForEach-Object {
                    if ($feature -eq $_) {
                        $appJson.features += $_
                    }
                }
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "SupportedLocales" } | ForEach-Object { 
            $first = $true
            $_.GetEnumerator() | ForEach-Object {
                if ($first) {
                    $appJson += @{ "supportedLocales" = @() }
                    $first = $false
                }
                $appJson.supportedLocales += @($_.Local)
            }
        }
        if ($runtime -ge [System.Version]"4.0")  {
            $first = $true
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "internalsVisibleTo" } | ForEach-Object { 
                if ($first) {
                    $appJson += @{
                        "internalsVisibleTo" = @()
                    }
                }
                $_.GetEnumerator() | ForEach-Object {
                    $appJson.internalsVisibleTo += [ordered]@{
                        "id" = $_.Id
                        "publisher" = $_.publisher
                        "name" = $_.name
                    }
                }
            }
        }
        if ($runtime -ge [System.Version]"6.0") {
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "preprocessorSymbols" } | ForEach-Object { 
                $first = $true
                $_.GetEnumerator() | ForEach-Object {
                    if ($first) {
                        $appJson += @{ "preprocessorSymbols" = @() }
                        $first = $false
                    }
                    $appJson.preprocessorSymbols += @($_.Name)
                }
            }
            $appJson += @{ "keyVaultUrls" = @() }
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "KeyVaultUrls" } | ForEach-Object { 
                $_.GetEnumerator() | ForEach-Object {
                    $appJson.keyVaultUrls += @($_.Name)
                }
            }
        }
        $appJson | convertTo-json | Set-Content -Path (Join-Path $appFolder "app.json") -Encoding UTF8
    }

    if ($openFolder) {
        Start-Process $appFolder
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    Set-StrictMode -Version 2.0
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Extract-AppFileToFolder
