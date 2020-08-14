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
 .Parameter showMyCode
  With this parameter you can change or check ShowMyCode in the app file. Check will throw an error if ShowMyCode is False.
 .Example
  Replace-DependenciesInAppFile -containerName test -Path c:\temp\myapp.app -replaceDependencies @{ "437dbf0e-84ff-417a-965d-ed2bb9650972" = @{ "id" = "88b7902e-1655-4e7b-812e-ee9f0667b01b"; "name" = "MyBaseApp"; "publisher" = "Freddy Kristiansen"; "minversion" = "1.0.0.0" }}
#>
Function Replace-DependenciesInAppFile {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $Path,
        [string] $Destination = $Path,
        [Parameter(Mandatory=$true)]
        [hashtable] $replaceDependencies,
        [ValidateSet('Ignore','True','False','Check')]
        [string] $ShowMyCode = "Ignore"
    )

    if ($path -ne $Destination) {
        Copy-Item -Path $path -Destination $Destination -Force
        $path = $Destination
    }
    
    Invoke-ScriptInBCContainer -containerName $containerName -scriptBlock { Param($path, $Destination, $replaceDependencies, $ShowMyCode)
    
        add-type -path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\system.io.packaging.dll").FullName
    
        $memoryStream = $null
        $fs = $null
    
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
        
            $memoryStream = [System.IO.MemoryStream]::new()
            $fs.Seek($metadataSize, [System.IO.SeekOrigin]::Begin) | Out-Null
            $fs.CopyTo($memoryStream)
            $memoryStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $memoryStream.SetLength($contentLength)
            $fs.Close()
            $fs.Dispose()
            $fs = $null
            
            $package = [System.IO.Packaging.Package]::Open($memoryStream, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
            $manifestPart = $package.GetPart('/NavxManifest.xml')
            $manifest = [xml]([System.IO.StreamReader]::new($manifestPart.GetStream())).ReadToEnd()
            $changes = $false
    
            if ($ShowMyCode -ne "Ignore") {
                if ($ShowMyCode -eq "Check") {
                    if ($manifest.Package.App.ShowMyCode -eq "False") {
                        throw "Application has ShowMyCode set to False"
                    }
                } elseif ($manifest.Package.App.ShowMyCode -ne $ShowMyCode) {
                    Write-Host "Changing ShowMyCode to $ShowMyCOde"
                    $manifest.Package.App.ShowMyCode = "$ShowMyCode"
                    $changes = $true
                }
            }
            if ($replaceDependencies) {
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
            }
    
            if ($changes) {
    
                $partStream = $manifestPart.GetStream([System.IO.FileMode]::Create)
                $manifest.Save($partStream)
                $partStream.Flush()
                $package.Close()
                
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
                
                $fs.Close()
                $fs.Dispose()
                $fs = $null
            }
            else {
                if ($Path -ne $Destination) {
                    Copy-Item -Path $Path -Destination $Destination -Force
                }
            }
        }
        finally {
            if ($fs) {
                $fs.Close()
            }
        }
    } -argumentList (Get-BCContainerPath -containerName $containerName -path $path -throw), (Get-BCContainerPath -containerName $containerName -path $Destination -throw), $replaceDependencies, $ShowMyCode
}
Export-ModuleMember -Function Replace-DependenciesInAppFile
