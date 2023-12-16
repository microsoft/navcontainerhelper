<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Create a new Business Central NuGet Package
 .Description
  Create a new NuGet package containing a Business Central apps
 .Parameter appfile
  App file to include in the NuGet package
 .Parameter packageId
  Id of the NuGet package (or template to generate the id, replacing {id}, {name} and {publisher} with the values from the app.json file) 
  The default is '{publisher}.{name}.{id}'
 .Parameter packageVersion
  Version of the NuGet package
  The default is the version number from the app.json file
 .Parameter prereleaseTag
  If this is a prerelease, then you can specify a prerelease tag, which will be appended to the version number of the NuGet package (together with a dash)
 .Parameter packageTitle
  Title of the NuGet package
  The default is the name from the app.json file
 .Parameter packageDescription
  Description of the NuGet package
  The default is the description from the app.json file
  If no description exists in the app.json file, the default is the package title
 .Parameter packageAuthors
  Authors of the NuGet package
  The default is the publisher from the app.json file
 .Parameter githubRepository
  URL to the GitHub repository for the NuGet package
 .Parameter dependencyIdTemplate
  Template to calculate the id of the dependencies
  The template can contain {id}, {name} and {publisher} which will be replaced with the values from the corresponding dependency from app.json
  The default is '{publisher}.{name}.{id}'
 .Example
  $package = New-BcNuGetPackage -appfile "C:\Users\freddyk\Downloads\MyBingMaps-main-Apps-1.0.3.0\Freddy Kristiansen_BingMaps.PTE_4.4.3.0.app"
 .Example
  $package = New-BcNuGetPackage -appfile $appfile -packageId "AL-Go-{id}" -dependencyIdTemplate "AL-Go-{id}"
#>
Function New-BcNuGetPackage {
    Param(
        [Parameter(Mandatory=$true)]
        [alias('appFiles')]
        [string] $appfile,
        [Parameter(Mandatory=$false)]
        [string] $packageId = "{publisher}.{name}.{id}",
        [Parameter(Mandatory=$false)]
        [System.Version] $packageVersion = $null,
        [Parameter(Mandatory=$false)]
        [string] $prereleaseTag = '',
        [Parameter(Mandatory=$false)]
        [string] $packageTitle = "",
        [Parameter(Mandatory=$false)]
        [string] $packageDescription = "",
        [Parameter(Mandatory=$false)]
        [string] $packageAuthors = "",
        [Parameter(Mandatory=$false)]
        [string] $githubRepository = "",
        [Parameter(Mandatory=$false)]
        [string] $dependencyIdTemplate = '{publisher}.{name}.{id}',
        [Parameter(Mandatory=$false)]
        [string] $applicationDependencyId = 'Microsoft.Application',
        [Parameter(Mandatory=$false)]
        [string] $platformDependencyId = 'Microsoft.Platform',
        [obsolete('NuGet Dependencies are always included.')]
        [switch] $includeNuGetDependencies
    )

    function CopyFileToStream([string] $filename, [System.IO.Stream] $stream) {
        $bytes = [System.IO.File]::ReadAllBytes($filename)
        $stream.Write($bytes,0,$bytes.Length)
    }

    Write-Host "Create NuGet package"
    Write-Host "AppFile:"
    Write-Host $appFile
    if (!(Test-Path $appFile)) {
        throw "Unable to locate file: $_"
    }
    $appFile = (Get-Item $appfile).FullName
    $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
    $rootFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
    New-Item -Path $rootFolder -ItemType Directory | Out-Null
    try {
        Copy-Item -Path $appFile -Destination $rootFolder -Force
        Extract-AppFileToFolder -appFilename $appFile -generateAppJson -appFolder $tmpFolder
        $appJsonFile = Join-Path $tmpFolder 'app.json'
        $appJson = Get-Content $appJsonFile -Encoding UTF8 | ConvertFrom-Json
        $packageId = $packageId.replace('{id}',$appJson.id).replace('{name}',[nuGetFeed]::Normalize($appJson.name)).replace('{publisher}',[nuGetFeed]::Normalize($appJson.publisher))
        if ($null -eq $packageVersion) {
            $packageVersion = [System.Version]$appJson.version
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

        if ($prereleaseTag) {
            $packageVersionStr = "$($packageVersion)-$prereleaseTag"
        }
        else {
            $packageVersionStr = "$packageVersion"
        }
        $nuPkgFileName = "$($packageId)-$($packageVersionStr).nupkg"
        $nupkgFile = Join-Path ([System.IO.Path]::GetTempPath()) $nuPkgFileName
        if (Test-Path $nuPkgFile -PathType Leaf) {
            Remove-Item $nupkgFile -Force
        }
        $nuspecFileName = Join-Path $rootFolder "manifest.nuspec"
        $xmlObjectsettings = New-Object System.Xml.XmlWriterSettings
        $xmlObjectsettings.Indent = $true
        $xmlObjectsettings.IndentChars = "    "
        $xmlObjectsettings.Encoding = [System.Text.Encoding]::UTF8
        $XmlObjectWriter = [System.XML.XmlWriter]::Create($nuspecFileName, $xmlObjectsettings)
        $XmlObjectWriter.WriteStartDocument()
        $XmlObjectWriter.WriteStartElement("package", "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd")
        $XmlObjectWriter.WriteStartElement("metadata")
        $XmlObjectWriter.WriteElementString("id", $packageId)
        $XmlObjectWriter.WriteElementString("version", $packageVersionStr)
        $XmlObjectWriter.WriteElementString("title", $packageTitle)
        $XmlObjectWriter.WriteElementString("description", $packageDescription)
        $XmlObjectWriter.WriteElementString("authors", $packageAuthors)
        if ($githubRepository) {
            $XmlObjectWriter.WriteStartElement("repository")
            $XmlObjectWriter.WriteAttributeString("type", "git");
            $XmlObjectWriter.WriteAttributeString("url", $githubRepository)
            $XmlObjectWriter.WriteEndElement()
        }
        $XmlObjectWriter.WriteStartElement("dependencies")
        $appJson.dependencies | ForEach-Object {
            $id = $dependencyIdTemplate.replace('{id}',$_.id).replace('{name}',[nuGetFeed]::Normalize($_.name)).replace('{publisher}',[nuGetFeed]::Normalize($_.publisher))
            $XmlObjectWriter.WriteStartElement("dependency")
            $XmlObjectWriter.WriteAttributeString("id", $id)
            $XmlObjectWriter.WriteAttributeString("version", $_.Version)
            $XmlObjectWriter.WriteEndElement()
        }
        if ($appJson.PSObject.Properties.Name -eq 'Application' -and $appJson.Application) {
            $XmlObjectWriter.WriteStartElement("dependency")
            $XmlObjectWriter.WriteAttributeString("id", $applicationDependencyId)
            $XmlObjectWriter.WriteAttributeString("version", $appJson.Application)
            $XmlObjectWriter.WriteEndElement()
        }
        if ($appJson.PSObject.Properties.Name -eq 'Platform' -and  $appJson.Platform) {
            $XmlObjectWriter.WriteStartElement("dependency")
            $XmlObjectWriter.WriteAttributeString("id", $platformDependencyId)
            $XmlObjectWriter.WriteAttributeString("version", $appJson.Platform)
            $XmlObjectWriter.WriteEndElement()
        }
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteStartElement("files")
        $XmlObjectWriter.WriteStartElement("file")
        $appFileName = [System.IO.Path]::GetFileName($appfile)
        $XmlObjectWriter.WriteAttributeString("src", $appFileName );
        $XmlObjectWriter.WriteAttributeString("target", $appFileName);
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndDocument()
        $XmlObjectWriter.Flush()
        $XmlObjectWriter.Close()
        
        Write-Host "NUSPEC file:"
        Get-Content -path $nuspecFileName -Encoding UTF8 | Out-Host
        $nuPkgFileName = "$($packageId)-$($packageVersion).nupkg"
        $nupkgFile = Join-Path ([System.IO.Path]::GetTempPath()) $nuPkgFileName
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
        Remove-Item -Path $tmpFolder -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $rootFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Export-ModuleMember -Function New-BcNuGetPackage
