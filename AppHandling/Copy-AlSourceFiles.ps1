<# 
 .Synopsis
  Copy AL Source Files
 .Description
  This function will copy all .al and .xlf files from Path to Destination.
  Information about each file will be sent to the alFileStructure function to determine the relative location of the file.
 .Parameter Path
  Source Path from where you want to copy all AL source files
 .Parameter Destination
  Destination Path
 .Parameter Recurse
  Copy source in subfolders
 .Parameter alFileStructure
  Specify a function, which will determine the location of the individual al source files
 .Example
  Copy-AlSourceFiles -Path "$sourceFolder\*" -Destination $destinationFolder -Recurse -alFileStructure $TypeFolders

#>
function Copy-AlSourceFiles {
    Param (
        [string] $Path,
        [string] $Destination,
        [switch] $Recurse,
        [ScriptBlock] $alFileStructure
    )

    Write-Host "Copying Al Source Files from $Path to $Destination"

    if ($alFileStructure) {
        $types = @('enum', 'page', 'table', 'codeunit', 'report', 'query', 'xmlport', 'profile', 'dotnet', 'enumextension', 'pageextension', 'tableextension', 'interface', 'entitlement', 'permissionset', 'permissionsetextension')
        $extensions = @(".al",".xlf",".lcl")

        $files = Get-ChildItem -Path $Path -Recurse:$Recurse
        $files | Where-Object { ($extensions.Contains($_.Extension.ToLowerInvariant())) -and !($_.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) } | ForEach-Object {
    
            $filename = $_.Name
            $content = [System.IO.File]::ReadAllLines($_.FullName)

            try {
                if ($_.Extension -ne ".al") {
                    $type = $_.Extension
                    $id = ''
                    $name = $_.BaseName
                } 
                else {
                    $found = $false
                    foreach($Line in $content) {
                        if (-not $found) {
                            $line = $Line.Trim()
                            $idx = $line.IndexOf(' ')
                            if ($idx -lt 0) {
                                $type = $line
                            }
                            else {
                                $type = $line.SubString(0,$idx).ToLowerInvariant()
                            }
                            if ($types.Contains($type)) {
                                $found = $true
                                break
                            }
                        } 
                    }
    
                    if ($type -eq "dotnet") {
                        $id = ''
                        $name = $_.BaseName
                    }
                    else {
                        $line = $line.SubString($type.Length).TrimStart()
                        if ($type -eq "profile" -or $type -eq "interface" -or $type -eq "entitlement") {
                            $id = ''
                        }
                        else {
                            $id = $line.SubString(0,$line.IndexOf(' '))
                            $line = $line.SubString($id.Length).Trim()
                        }
                        if ($line.StartsWith('"')) {
                            $nameendidx = $line.IndexOf('"',1)
                            $name = $line.SubString(1,$nameendidx-1)
                        }
                        else {
                            $name = $line
                        }
                    }
                }
                if ($alFileStructure.Ast.ParamBlock.Parameters.Count -eq 3) {
                    $newFilename = "$($alFileStructure.Invoke($type, $id, $name))"
                }
                else {
                    $newFilename = "$($alFileStructure.Invoke($type, $id, $name, [ref] $content))"
                }
    
                if ($newFilename) {
                    $newFilename = $newFilename -replace '[~#%&*{}|:<>?/"]', ''
 
                    $destFilename = Join-Path $Destination $newFilename
                    $destPath = [System.IO.Path]::GetDirectoryName($destFilename)
                    $destName = [System.IO.Path]::GetFileName($destFilename)
                    
                    if (-not (Test-Path $destPath)) {
                        New-Item $destPath -ItemType Directory | Out-Null
                    }

                    if (Test-Path -Path $destFilename) {
                        Write-Warning "$destFilename already exists, adding sequence number"
                        $seq = 1
                        $dotIdx = $destName.IndexOf('.')
                        if ($dotIdx -lt 0) {
                            throw "Cannot add sequence number to $destName"
                        }
                        while (Test-Path -Path $destFilename) {
                            $seq++
                            $destFilename = Join-Path $destPath $destName.Insert($dotIdx,"$seq")
                        }
                    }

                    if ($type -eq "report") {
                        0..($content.Count-1) | % {
                            $line = $content[$_]
                            if ($line.Trim() -like "RDLCLayout = '*';" -or $line.Trim() -like "WordLayout = '*';") {
                                $startIdx = $line.IndexOf("'")+1
                                $endIdx = $line.LastIndexOf("'")
                                $layoutFilename = $line.SubString($startIdx, $endIdx-$startIdx)
                                $layoutFilename = $layoutFilename.SubString($layoutFilename.LastIndexOfAny(@('\','/'))+1)
                                $layoutFile = $Files | Where-Object { $_.name -eq $layoutFilename }
                                if ($layoutFile) {
                                    $layoutcontent = [System.IO.File]::ReadAllBytes($layoutFile.FullName)
        
                                    if ($alFileStructure.Ast.ParamBlock.Parameters.Count -eq 3) {
                                        $layoutNewFilename = "$($alFileStructure.Invoke($layoutFile.Extension, $id, $name))"
                                    }
                                    else {
                                        $layoutNewFilename = "$($alFileStructure.Invoke($layoutFile.Extension, $id, $name, [ref] $content))"
                                    }

                                    if ($layoutNewFilename) {
                                        if ($layoutNewFilename.StartsWith('*\')) {
                                            $layoutDestFilename = Join-Path $DestPath $layoutNewFilename.Substring(2)
                                            $layoutDestPath = [System.IO.Path]::GetDirectoryName($layoutDestFilename)
                                            $layoutDestName = [System.IO.Path]::GetFileName($layoutDestFilename)
                                            if ($layoutDestName.StartsWith('*.')) {
                                                $layoutDestName = [System.IO.Path]::GetFileNameWithoutExtension($destFileName) + $layoutDestName.Substring(1)
                                                $layoutDestFileName = Join-Path $layoutDestPath $layoutDestName
                                            }
                                        }
                                        elseif ($layoutNewFilename.StartsWith('*.')) {
                                            $layoutDestPath = $destPath
                                            $layoutDestName = [System.IO.Path]::GetFileNameWithoutExtension($destFileName) + $layoutNewFilename.Substring(1)
                                            $layoutDestFilename = Join-Path $layoutDestPath $layoutDestName
                                        }
                                        else {
                                            $layoutNewFilename = $layoutNewFilename -replace '[~#%&*{}|:<>?/"]', ''
    
                                            $layoutDestFilename = Join-Path $Destination $layoutNewFilename
                                            $layoutDestPath = [System.IO.Path]::GetDirectoryName($layoutDestFilename)
                                            $layoutDestName = [System.IO.Path]::GetFileName($layoutDestFilename)
                                        }
    
                                        if (-not (Test-Path $layoutDestPath)) {
                                            New-Item $layoutDestPath -ItemType Directory | Out-Null
                                        }
    
                                        if (Test-Path -Path $layoutDestFilename) {
                                            Write-Warning "$layoutDestFilename already exists, adding sequence number"
                                            $seq = 1
                                            $dotIdx = $layoutDestName.IndexOf('.')
                                            if ($dotIdx -lt 0) {
                                                throw "Cannot add sequence number to $layoutDestName"
                                            }
                                            while (Test-Path -Path $layoutDestFilename) {
                                                $seq++
                                                $layoutDestFilename = Join-Path $layoutDestPath $layoutDestName.Insert($dotIdx,"$seq")
                                            }
                                        }

                                        [System.IO.File]::WriteAllBytes($layoutDestFilename, $layoutcontent)

                                        $filename = (get-item $layoutDestFilename).FullName
                                        if ($filename.StartsWith($Destination,"InvariantCultureIgnoreCase")) {
                                            $layoutDestFilename = $filename
                                        }
            
                                        $content[$_] = $line.SubString(0,$startIdx) + $layoutDestFilename.Substring($destination.Length+1).Replace('\','/') + $line.SubString($endIdx)
                                    }
                                }
                                else {
                                    Write-Warning "Unable to find $layoutFilename"
                                }
                            }
                        }
                    }
        
                    [System.IO.File]::WriteAllLines($destFileName, $content)
                }
            }
            catch {
                Write-Warning "Unexpected error while handling $filename"
                throw
            }
        }
    }
    else {
        Copy-Item -Path $Path -Destination $Destination -Recurse:$Recurse -Force | Out-Null
    }
}
Export-ModuleMember -Function Copy-AlSourceFiles
