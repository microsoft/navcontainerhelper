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
 .Example
  Extract-AppFileToFolder -appFilename c:\temp\baseapp.app
#>
function Extract-AppFileToFolder {
    Param (
        [string] $appFilename,
        [string] $appFolder = "$($appFilename).source",
        [switch] $generateAppJson
    )

    if ("$appFolder" -eq "$hostHelperFolder" -or "$appFolder" -eq "$hostHelperFolder\") {
        throw "The folder specified in ObjectsFolder will be erased, you cannot specify $hostHelperFolder"
    }

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

    if ($generateAppJson) {
        #Set-StrictMode -Off
        $manifest = [xml](Get-Content -path (Join-Path $appFolder "NavxManifest.xml"))
        $appJson = [ordered]@{
            "id" = $manifest.Package.App.Id
            "name" = $manifest.Package.App.Name
            "publisher" = $manifest.Package.App.Publisher
            "version" = $manifest.Package.App.Version
            "brief" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Brief" } | % { $_.Value } )"
            "description" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Description" } | % { $_.Value } )"
            "platform" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Platform" } | % { $_.Value } )"
            "application" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Application" } | % { $_.Value } )"
            "showMyCode" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "ShowMyCode" } | % { $_.Value } )" -eq "True"
            "runtime" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Runtime" } | % { $_.Value } )"
            "logo" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Logo" } | % { $_.Value } )".TrimStart('/')
            "url" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Url" } | % { $_.Value } )"
            "EULA" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "EULA" } | % { $_.Value } )"
            "privacyStatement" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "PrivacyStatement" } | % { $_.Value } )"
            "help" = "$($manifest.Package.App.Attributes | Where-Object { $_.name -eq "Help" } | % { $_.Value } )"
            "screenshots" = @()
            "dependencies" = @()
            "idRanges" = @()
            "features" = @()
        }
        $manifest.Package.ChildNodes | Where-Object { $_.name -eq "Dependencies" } | % { 
            $_.GetEnumerator() | % {
                $appJson.dependencies += [ordered]@{
                    "appId" = $_.Id
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
                'TranslationFile','GenerateCaptions' | % {
                    if ($feature -eq $_) {
                        $appJson.features += $_
                    }
                }
            }
        }
        $appJson | convertTo-json | Set-Content -Path (Join-Path $appFolder "app.json")
        Set-StrictMode -Version 2.0
    }
}
Export-ModuleMember -Function Extract-AppFileToFolder
