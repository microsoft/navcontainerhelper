<# 
 .Synopsis
  Extract the content of an App File to a Folder
 .Description
 .Parameter AppFilename
  Path of the application file
 .Parameter AppFolder
  Path of the folder in which the application File will be unpacked. If this folder exists, the content will be deleted. Default is $appFile.source.
 .Example
  Extract-AppFileToFolder -appFilename c:\temp\baseapp.app
#>
function Extract-AppFileToFolder {
    Param (
        [string] $appFilename,
        [string] $appFolder = "$($appFilename).source"
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
            $fullname = Join-Path $appFolder $_.FullName
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
}
Export-ModuleMember -Function Extract-AppFileToFolder
