<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Create a new Business Central NuGet Package
 .Description
  Create a new NuGet package containing a Business Central apps
 .Parameter appfile
  App file to include in the NuGet package
 .Parameter countrySpecificAppFiles
  Hashtable with country specific app files (runtime packages) to include in the NuGet package
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
 .Parameter destinationFolder
  Folder to create the NuGet package in. Defeault it to create a temporary folder and delete it after the NuGet package has been created
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
        [hashtable] $countrySpecificAppFiles = @{},
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
        [string] $applicationDependency = '',
        [Parameter(Mandatory=$false)]
        [string] $platformDependencyId = 'Microsoft.Platform',
        [Parameter(Mandatory=$false)]
        [string] $runtimeDependencyId = '{publisher}.{name}.runtime-{version}',
        [switch] $isIndirectPackage,
        [Parameter(Mandatory=$false)]
        [string] $destinationFolder = '',
        [obsolete('NuGet Dependencies are always included.')]
        [switch] $includeNuGetDependencies
    )

    function CopyFileToStream([string] $filename, [System.IO.Stream] $stream) {
        $bytes = [System.IO.File]::ReadAllBytes($filename)
        $stream.Write($bytes,0,$bytes.Length)
    }

    function CalcPackageId([string] $packageIdTemplate, [string] $publisher, [string] $name, [string] $id, [string] $version) {
        $name = [nuGetFeed]::Normalize($name)
        $publisher = [nuGetFeed]::Normalize($publisher)
        $packageId = $packageIdTemplate.replace('{id}',$id).replace('{name}',$name).replace('{publisher}',$publisher).replace('{version}',$version)
        if ($packageId.Length -ge 100) {
            if ($name.Length -gt ($packageId.Length - 99)) {
                $name = $name.Substring(0, $name.Length - ($packageId.Length - 99))
            }
            else {
                throw "Package id is too long: $packageId, unable to shorten it"
            }
            $packageId = $packageIdTemplate.replace('{id}',$id).replace('{name}',$name).replace('{publisher}',$publisher).replace('{version}',$version)
        }
        return $packageId
    }

    Write-Host "Create NuGet package"
    Write-Host "AppFile:"
    Write-Host $appFile
    if (!(Test-Path $appFile)) {
        throw "Unable to locate file: $_"
    }
    $appFile = (Get-Item $appfile).FullName
    if ($destinationFolder) {
        $rootFolder = $destinationFolder
    }
    else {
        $rootFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
    }
    if (Test-Path $rootFolder) {
        if (Get-ChildItem -Path $rootFolder) {
            throw "Destination folder is not empty"
        }
    }
    else {
        New-Item -Path $rootFolder -ItemType Directory | Out-Null
    }
    try {
        if (!$isIndirectPackage.IsPresent) {
            Copy-Item -Path $appFile -Destination $rootFolder -Force
            if ($countrySpecificAppFiles) {
                foreach($country in $countrySpecificAppFiles.Keys) {
                    $countrySpecificAppFile = $countrySpecificAppFiles[$country]
                    if (!(Test-Path $countrySpecificAppFile)) {
                        throw "Unable to locate file: $_"
                    }
                    $countryFolder = Join-Path $rootFolder $country 
                    New-Item -Path $countryFolder -ItemType Directory | Out-Null
                    Copy-Item -Path $countrySpecificAppFile -Destination $countryFolder -Force
                }
            }
        }
        $appJson = Get-AppJsonFromAppFile -appFile $appFile
        $packageId = CalcPackageId -packageIdTemplate $packageId -publisher $appJson.publisher -name $appJson.name -id $appJson.id -version $appJson.version.replace('.','-')
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
        if (-not $applicationDependency) {
            if ($appJson.PSObject.Properties.Name -eq 'Application' -and $appJson.Application) {
                $applicationDependency = $appJson.Application
            }
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
        if ($appJson.PSObject.Properties.Name -eq 'dependencies') {
            $appJson.dependencies | ForEach-Object {
                $id = CalcPackageId -packageIdTemplate $dependencyIdTemplate -publisher $_.publisher -name $_.name -id $_.id -version $_.version.replace('.','-')
                $XmlObjectWriter.WriteStartElement("dependency")
                $XmlObjectWriter.WriteAttributeString("id", $id)
                $XmlObjectWriter.WriteAttributeString("version", $_.Version)
                $XmlObjectWriter.WriteEndElement()
            }
        }
        if ($applicationDependency) {
            $XmlObjectWriter.WriteStartElement("dependency")
            $XmlObjectWriter.WriteAttributeString("id", $applicationDependencyId)
            $XmlObjectWriter.WriteAttributeString("version", $applicationDependency)
            $XmlObjectWriter.WriteEndElement()
        }
        if ($appJson.PSObject.Properties.Name -eq 'Platform' -and  $appJson.Platform) {
            $XmlObjectWriter.WriteStartElement("dependency")
            $XmlObjectWriter.WriteAttributeString("id", $platformDependencyId)
            $XmlObjectWriter.WriteAttributeString("version", $appJson.Platform)
            $XmlObjectWriter.WriteEndElement()
        }
        if ($isIndirectPackage.IsPresent) {
            $XmlObjectWriter.WriteStartElement("dependency")
            $id = CalcPackageId -packageIdTemplate $runtimeDependencyId -publisher $appJson.publisher -name $appJson.name -id $appJson.id -version $appJson.version.replace('.','-')
            $XmlObjectWriter.WriteAttributeString("id", $id)
            $XmlObjectWriter.WriteAttributeString("version", '1.0.0.0')
            $XmlObjectWriter.WriteEndElement()
        }
        $XmlObjectWriter.WriteEndElement()
        $XmlObjectWriter.WriteEndElement()
        if (!$isIndirectPackage.IsPresent) {
            $XmlObjectWriter.WriteStartElement("files")
            $XmlObjectWriter.WriteStartElement("file")
            $appFileName = [System.IO.Path]::GetFileName($appfile)
            $XmlObjectWriter.WriteAttributeString("src", $appFileName );
            $XmlObjectWriter.WriteAttributeString("target", $appFileName);
            $XmlObjectWriter.WriteEndElement()
            if ($countrySpecificAppFiles) {
                foreach($country in $countrySpecificAppFiles.Keys) {
                    $countrySpecificAppFile = $countrySpecificAppFiles[$country]
                    $XmlObjectWriter.WriteStartElement("file")
                    $appFileName = Join-Path $country ([System.IO.Path]::GetFileName($countrySpecificAppFiles[$country]))
                    $XmlObjectWriter.WriteAttributeString("src", $appFileName );
                    $XmlObjectWriter.WriteAttributeString("target", $appFileName);
                    $XmlObjectWriter.WriteEndElement()
                }
            }
            $XmlObjectWriter.WriteEndElement()
        }
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
        if ($destinationFolder -ne $rootFolder) {
            Remove-Item -Path $rootFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
Export-ModuleMember -Function New-BcNuGetPackage
