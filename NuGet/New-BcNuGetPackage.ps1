<# 
 .Synopsis
  POC PREVIEW: Create a new Business Central NuGet Package
 .Description
  Create a new NuGet package containing one or more Business Central apps
 .Parameter useRuntimePackages
  Include this switch to 
 .Parameter appfiles
 .Parameter dependencyAppFiles
 .Parameter testAppFiles
 .Parameter packageId
 .Parameter packageVersion
 .Parameter packageTitle
 .Parameter packageDescription
 .Parameter packageAuthors
 .Parameter githubRepository
 .Parameter includeNuGetDependencies
 .Example
  todo
#>
Function New-BcNuGetPackage {
    Param(
        [switch] $useRuntimePackages,
        [Parameter(Mandatory=$true)]
        [string[]] $appfiles,
        [string[]] $dependencyAppFiles = @(),
        [string[]] $testAppFiles = @(),
        [string] $packageId = "",
        [string] $packageVersion = "",
        [string] $packageTitle = "",
        [string] $packageDescription = "",
        [string] $packageAuthors = "",
        [string] $githubRepository = "",
        [switch] $includeNuGetDependencies
    )

    if ($useRuntimePackages) {
        throw "Runtime packages not yet supported"
    }

    $ok = $true
    $appFiles | Out-Host
    $dependencyAppFiles | Out-Host
    $testAppFiles | Out-Host
    $appFiles,$dependencyAppFiles,$testAppFiles | Where-Object { $_ } | ForEach-Object {
        if (-not (Test-Path $_)) {
            Write-Host -foregroundColor Red "Unable to locate file: $_"
            $ok = $false
        }
    }
    if (!$ok) {
        throw "Error Creating NuGet Package"
    }

    if ($appfiles.Count -eq 0) {
        throw "You need to specify at least one appfile"
    }
    elseif ($appfiles.Count -gt 1) {
        if ($packageId -eq "" -or $packageVersion -eq "" -or $packageTitle -eq "" -or $packageAuthors -eq "") {
            throw "When specifying multiple files, you need to specify packageId, packageVersion, packageTitle and packageAuthors"
        }
        if ($includeNuGetDependencies) {
            throw "includeNuGetDependencies is only supported when creating a NuGet package for a single app"
        }
    }

    $appFile = $appfiles | Select-Object -First 1
    $tmpFolder = Join-Path $ENV:TEMP ([GUID]::NewGuid().ToString())
    Extract-AppFileToFolder -appFilename $appFile -generateAppJson -appFolder $tmpFolder
    $appJsonFile = Join-Path $tmpFolder 'app.json'
    $appJson = Get-Content $appJsonFile -Encoding UTF8 | ConvertFrom-Json
    Remove-Item $tmpFolder -Recurse -Force

    $testsFolderName = "Tests"
    $dependenciesFolderName = "Dependencies"
    $rootFolder = Join-Path $ENV:TEMP ([GUID]::NewGuid().ToString())
    New-Item -Path $rootFolder -ItemType Directory | Out-Null
    try {
        $testsFolder = Join-Path $rootFolder $testsFolderName
        New-Item -Path $testsFolder -ItemType Directory | Out-Null
        $dependenciesFolder = Join-Path $rootFolder $dependenciesFolderName
        New-Item -Path $dependenciesFolder -ItemType Directory | Out-Null
        $appfiles | ForEach-Object {
            Copy-Item -Path $_ -Destination $rootFolder -Force
        }
        $testAppfiles | ForEach-Object {
            Copy-Item -Path $_ -Destination $testsFolder -Force
        }
        $dependencyAppfiles | ForEach-Object {
            Copy-Item -Path $_ -Destination $dependenciesFolder -Force
        }
        if ($packageId) {
            $packageId = $packageId.replace('{id}',$appJson.id).replace('{name}',$appJson.name).replace('{publisher}',$appJson.publisher)
        }
        else {
            $packageId = $appJson.id
        }
        if (-not $packageVersion) {
            $version = [System.Version]$appJson.version
            $packageVersion = "$($version.Major).$($version.Minor).$($version.Build).$($version.Revision)"
        }
        if (-not $packageTitle) {
            $packageTitle = $appJson.name
        }
        if (-not $packageDescription) {
            $packageDescription = $appJson.description
            if (-not $packageDescription) {
                $packageDescription = $packageTitle
            }
        }
        if (-not $packageAuthors) {
            $packageAuthors = $appJson.publisher
        }
        $nuspecFileName = Join-Path $rootFolder "manifest.nuspec"
        $xmlObjectsettings = New-Object System.Xml.XmlWriterSettings
        $xmlObjectsettings.Indent = $true
        $xmlObjectsettings.IndentChars = "�    "
        $xmlObjectsettings.Encoding = [System.Text.Encoding]::UTF8
        $XmlObjectWriter = [System.XML.XmlWriter]::Create($nuspecFileName, $xmlObjectsettings)
        $XmlObjectWriter.WriteStartDocument()
        $XmlObjectWriter.WriteStartElement("package", "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd")
        $XmlObjectWriter.WriteStartElement("metadata")
        $XmlObjectWriter.WriteElementString("id", $packageId)
        $XmlObjectWriter.WriteElementString("version", $packageVersion)
        $XmlObjectWriter.WriteElementString("title", $packageTitle)
        $XmlObjectWriter.WriteElementString("description", $packageDescription)
        $XmlObjectWriter.WriteElementString("authors", $packageAuthors)
        if ($githubRepository) {
            $XmlObjectWriter.WriteStartElement("repository")
            $XmlObjectWriter.WriteAttributeString("type", "git");
            $XmlObjectWriter.WriteAttributeString("url", $githubRepository);
            $XmlObjectWriter.WriteEndElement()
        }
        if ($includeNuGetDependencies) {
            $XmlObjectWriter.WriteStartElement("dependencies")
            $appJson.dependencies | ForEach-Object {
                $depVersion = [System.Version]$_.Version
                $XmlObjectWriter.WriteStartElement("dependency")
                $XmlObjectWriter.WriteAttributeString("id", $_.id);
                $XmlObjectWriter.WriteAttributeString("version", "$($depVersion.Major).$($depVersion.Minor).$($depVersion.Build)");
                $XmlObjectWriter.WriteEndElement()
            }
            $XmlObjectWriter.WriteEndElement()
        }
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteStartElement("files")
        $appFiles | ForEach-Object {
            $XmlObjectWriter.WriteStartElement("file")
            $appFileName = [System.IO.Path]::GetFileName($_)
            $XmlObjectWriter.WriteAttributeString("src", $appFileName );
            $XmlObjectWriter.WriteAttributeString("target", $appFileName);
            $XmlObjectWriter.WriteEndElement()
        }
        $testAppFiles | ForEach-Object {
            $XmlObjectWriter.WriteStartElement("file")
            $appFileName = [System.IO.Path]::GetFileName($_)
            $XmlObjectWriter.WriteAttributeString("src", "$testsFolderName\$appFileName" );
            $XmlObjectWriter.WriteAttributeString("target", "$testsFolderName\$appFileName" );
            $XmlObjectWriter.WriteEndElement()
        }
        $dependencyAppFiles | ForEach-Object {
            $XmlObjectWriter.WriteStartElement("file")
            $appFileName = [System.IO.Path]::GetFileName($_)
            $XmlObjectWriter.WriteAttributeString("src", "$dependenciesFolderName\$appFileName" );
            $XmlObjectWriter.WriteAttributeString("target", "$dependenciesFolderName\$appFileName" );
            $XmlObjectWriter.WriteEndElement()
        }
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndDocument()
        $XmlObjectWriter.Flush()
        $XmlObjectWriter.Close()
        
        $nuPkgFileName = "$($packageId)_$packageVersion.nupkg"
        $nupkgFile = Join-Path $ENV:TEMP $nuPkgFileName
        if (Test-Path $nuPkgFile -PathType Leaf) {
            Remove-Item $nupkgFile -Force
        }
        Compress-Archive -Path "$rootFolder\*" -DestinationPath "$nupkgFile.zip" -Force
        Rename-Item -Path "$nupkgFile.zip" -NewName $nuPkgFileName
        
        $size = (Get-Item $nupkgFile).Length
        if ($size -gt 1MB) {
            $sizeStr = "$([int]($size/1MB))Mb"
        }
        elseif ($size -gt 1KB) {
            $sizeStr = "$([int]($size/1KB))Kb"
        }
        else {
            $sizeStr = "$size bytes"
        }
        Write-Host -ForegroundColor Green "Successfully created NuGet package (Size: $sizeStr)"
        $nupkgFile
    }
    finally {
        Remove-Item -Path $rootFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Export-ModuleMember -Function New-BcNuGetPackage
