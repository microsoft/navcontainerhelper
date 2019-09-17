<# 
 .Synopsis
  Replaces specified dependencies in an application file
 .Description
  Investigates whether the application file contains dependencies to a specific application ID and replaces the dependency if that is the case
 .Parameter Path
  Path of the application file to investigate
 .Parameter Destination
  Path of the modified application file, where dependencies was replaced (default is to rewrite the original file)
 .Parameter replaceDependencies
  A hashtable, describring the dependencies, which needs to be replaced
 .Example
  Replace-DependenciesInAppFile -Path c:\temp\myapp.app -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
Function Replace-DependenciesInAppFile {
    Param (
        [string] $Path,
        [string] $Destination = $Path,
        [hashtable] $replaceDependencies
    )

    $zipArchive = $null
    $memoryStream = $null
    $fs = $null
    $binaryReader = $null
    $binaryWriter = $null
    $tempDir = (Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())) + "\"
    New-Item $tempDir -ItemType Directory | Out-Null

    try {

        $fs = [System.IO.File]::OpenRead($Path)
        $binaryReader = [System.IO.BinaryReader]::new($fs)
        $magicNumber1 = $binaryReader.ReadUInt32()
        $metadataSize = $binaryReader.ReadUInt32()
        $metadataVersion = $binaryReader.ReadUInt32()
        $packageId = [Guid]::new($binaryReader.ReadBytes(16))
        $contentLength = $binaryReader.ReadInt64()
        $magicNumber2 = $binaryReader.ReadUInt32()
        
        if ($magicNumber1 -ne 0x5856414E -or 
            $magicNumber2 -ne 0x5856414E -or 
            $metadataVersion -gt 2 -or
            $fs.Position + $contentLength -gt $fs.Length)
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
            $fullname = Join-Path $tempDir $_.FullName
            $dir = [System.IO.Path]::GetDirectoryName($fullname)
            if ($dir -ne $prevdir) {
                if (-not (Test-Path $dir -PathType Container)) {
                    New-Item -Path $dir -ItemType Directory | Out-Null
                }
            }
            $prevdir = $dir
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $fullname)
        }
        $zipArchive.Dispose()
        $zipArchive = $null
        $binaryReader.Close()
        $binaryReader = $null
        $fs.Close()
        $fs = $null

        $changes = $false
        $manifestFile = Join-Path $tempDir "NavxManifest.xml"
        $manifest = [xml](Get-Content $manifestFile)
        $manifest.Package.Dependencies.GetEnumerator() | % {
            $dependency = $_
            if ($replaceDependencies.ContainsKey($dependency.id)) {
                $newDependency = $replaceDependencies[$dependency.id]
                Write-Host "Replacing dependency from $($dependency.id) to $($newDependency.id)"
                $dependency.id = $newDependency.id
                $dependency.name = $newDependency.name
                $dependency.publisher = $newDependency.publisher
                $dependency.minVersion = $newDependency.minVersion
                $changes = $true
            }
        }

        if ($changes) {

            $manifest.Save($manifestFile)
            
            $memoryStream = [System.IO.MemoryStream]::new()
            $zipArchive = [System.IO.Compression.ZipArchive]::new($memoryStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
            $files = [System.IO.Directory]::EnumerateFiles($tempDir, "*.*", [System.IO.SearchOption]::AllDirectories)
            $files | % {
                $file = $_.SubString($tempDir.Length)
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $_, $file) | Out-Null
            }
            $zipArchive.Dispose()
            $zipArchive = $null
            
            $fs = [System.IO.FileStream]::new($Destination, [System.IO.FileMode]::Create)
        
            $binaryWriter = [System.IO.BinaryWriter]::new($fs)
            $binaryWriter.Write([UInt32](0x5856414E))
            $binaryWriter.Write([UInt32](40))
            $binaryWriter.Write([UInt32](2))
            $binaryWriter.Write($packageId.ToByteArray())
            $binaryWriter.Write([UInt64]($memoryStream.Length))
            $binaryWriter.Write([UInt32](0x5856414E))
            
            $memoryStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $memoryStream.CopyTo($fs)
        }
        else {
            if ($Path -ne $Destination) {
                Copy-Item -Path $Path -Destination $Destination -Force
            }
        }
    }
    finally {
        if ($zipArchive) {
            $zipArchive.Dispose()
        }
        if ($memoryStream) {
            $memoryStream.Close()
            $memoryStream.Dispose()
        }
        if ($binaryWriter) {
            $binaryWriter.Close()
        }
        if ($binaryReader) {
            $binaryReader.Close()
        }
        if ($fs) {
            $fs.Close()
        }
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}
Export-ModuleMember -Function Replace-DependenciesInAppFile
