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

    if ($appFolder -eq "") {
        if ($openFolder) {
            $generateAppJson = $true
            $appFolder = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
        }
        else {
            $appFolder = "$($appFilename).source"
        }
    }

    if ("$appFolder" -eq "$hostHelperFolder" -or "$appFolder" -eq "$hostHelperFolder\") {
        throw "The folder specified in ObjectsFolder will be erased, you cannot specify $hostHelperFolder"
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

    "/addin/src/", "/perm/", "/entit/", "/serv/", "/tabledata/", "/replay/", "/migration/", "/layout/" | % {
        $folder = Join-Path $appFolder $_
        if (Test-Path $folder) {
            @(Get-ChildItem $folder) | % {
                Copy-Item -Path $_.FullName -Destination $appFolder -Recurse -Force
                Remove-Item -Path $_.FullName -Recurse -Force
            }
        }
    }

    if ($generateAppJson) {
        #Set-StrictMode -Off
        $manifest = [xml](Get-Content -path (Join-Path $appFolder "NavxManifest.xml") -Encoding UTF8)
        $runtimeStr = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Runtime" } | % { $_.Value } )"
        if ($runtimeStr) {
            $runtime = [System.Version]$runtimeStr
        }
        else {
            $runtime = [System.Version]"9.2"
        }

        $application = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Application" } | % { $_.Value } )"
        $appJson = [ordered]@{
            "id" = $manifest.Package.App.Id
            "name" = $manifest.Package.App.Name
            "publisher" = $manifest.Package.App.Publisher
            "version" = $manifest.Package.App.Version
            "brief" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Brief" } | % { $_.Value } )"
            "description" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Description" } | % { $_.Value } )"
            "platform" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Platform" } | % { $_.Value } )"
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
            "logo" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Logo" } | % { $_.Value } )".TrimStart('/')
            "url" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Url" } | % { $_.Value } )"
            "EULA" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "EULA" } | % { $_.Value } )"
            "privacyStatement" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "PrivacyStatement" } | % { $_.Value } )"
            "help" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Help" } | % { $_.Value } )"
            "target" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "target" } | % { $_.Value } )"
            "screenshots" = @()
            "dependencies" = @()
            "idRanges" = @()
            "features" = @()
        }

        if ($runtime -lt [System.Version]"8.0")  {
            $appJson += @{
                "showMyCode" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "ShowMyCode" } | % { $_.Value } )" -eq "True"
            }
        }
        else {
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "ResourceExposurePolicy" } | % { 
                $xmlResExp = [ordered]@{}
                $resExp = [ordered]@{}
                "allowDebugging", "allowDownloadingSource", "includeSourceInSymbolFile" | % {
                    $prop = $_
                    if ($xmlResExp.PSObject.Properties.Name -eq $prop) {
                        $resExp += @{
                            "$prop" = $xmlResExp."$prop" -eq "true"
                        }
                    }
                }
                $appJson += @{ "resourceExposurePolicy" = $resExp }
            }
       
        }
        if ($runtime -ge [System.Version]"5.0")  {
            $appInsightsKey = $manifest.Package.App.Attributes | Where-Object { $_.name -eq "applicationInsightsKey" } | % { $_.Value } 
            if ($appInsightsKey) {
                $appJson += @{
                    "applicationInsightsKey" = "$appInsightsKey"
                }
            }
            elseif ($runtime -ge [System.Version]"7.2")  {
                $appInsightsConnectionString = $manifest.Package.App.Attributes | Where-Object { $_.name -eq "applicationInsightsConnectionString" } | % { $_.Value } 
                if ($appInsightsConnectionString) {
                    $appJson += @{
                        "applicationInsightsConnectionString" = "$appInsightsConnectionString"
                    }
                }
            }
        }
        $contextSensitiveHelpUrl = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "contextSensitiveHelpUrl" } | % { $_.Value } )"
        if ($contextSensitiveHelpUrl) {
            $appJson += @{
                "contextSensitiveHelpUrl" = $contextSensitiveHelpUrl
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Dependencies" } | % { 
            $_.GetEnumerator() | % {
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
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "IdRanges" } | % { 
            $_.GetEnumerator() | % {
                $appJson.idRanges += [ordered]@{
                    "from" = [Int]::Parse($_.MinObjectId)
                    "to" = [Int]::Parse($_.MaxObjectId)
                }
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Features" } | % { 
            $_.GetEnumerator() | % {
                $feature = $_.'#text'
                'ExcludeGeneratedTranslations','GenerateCaptions','GenerateLockedTranslations','NoImplicitWith','TranslationFile' | % {
                    if ($feature -eq $_) {
                        $appJson.features += $_
                    }
                }
            }
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "SupportedLocales" } | % { 
            $first = $true
            $_.GetEnumerator() | % {
                if ($first) {
                    $appJson += @{ "supportedLocales" = @() }
                    $first = $false
                }
                $appJson.supportedLocales += @($_.Local)
            }
        }
        if ($runtime -ge [System.Version]"4.0")  {
            $first = $true
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "internalsVisibleTo" } | % { 
                if ($first) {
                    $appJson += @{
                        "internalsVisibleTo" = @()
                    }
                }
                $_.GetEnumerator() | % {
                    $appJson.internalsVisibleTo += [ordered]@{
                        "id" = $_.Id
                        "publisher" = $_.publisher
                        "name" = $_.name
                    }
                }
            }
        }
        if ($runtime -ge [System.Version]"6.0") {
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "preprocessorSymbols" } | % { 
                $first = $true
                $_.GetEnumerator() | % {
                    if ($first) {
                        $appJson += @{ "preprocessorSymbols" = @() }
                        $first = $false
                    }
                    $appJson.preprocessorSymbols += @($_.Name)
                }
            }
            $appJson += @{ "keyVaultUrls" = @() }
            $manifest.Package.ChildNodes | Where-Object { $_.name -eq "KeyVaultUrls" } | % { 
                $_.GetEnumerator() | % {
                    $appJson.keyVaultUrls += @($_.Name)
                }
            }
        }
        $appJson | convertTo-json | Set-Content -Path (Join-Path $appFolder "app.json") -Encoding UTF8
        Set-StrictMode -Version 2.0
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
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Extract-AppFileToFolder
