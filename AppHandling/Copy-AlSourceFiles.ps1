<# 
 .Synopsis
  Copy AL Source Files
 .Description
 .Parameter Path
 .Parameter Destination
 .Parameter Recurse
 .Parameter alFileStructure
 .Example
  Copy-AlSourceFiles -Path "$sourceFolder\*" -Destination $destinationFolder -Recurse -alFileStructure $TypeFolders

#>
function Copy-AlSourceFiles {

    Param(
        [string] $Path,
        [string] $Destination,
        [switch] $Recurse,
        [ScriptBlock] $alFileStructure
    )

    Write-Host "Copying Al Source Files from $Path to $Destination"

    if ($alFileStructure) {
        $types = @('enum', 'page', 'table', 'codeunit', 'report', 'query', 'xmlport', 'profile', 'dotnet', 'enumextension', 'pageextension', 'tableextension')
        
        $files = Get-ChildItem -Path $Path -Recurse:$Recurse
        $files | Where-Object { ($_.Extension -eq '.al' -or $_.Extension -eq '.xlf') -and !($_.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) } | ForEach-Object {
    
            $filename = $_.Name
            $content = [System.IO.File]::ReadAllLines($_.FullName)

            try {
                if ($_.Extension -eq '.xlf') {
                    $type = $_.Extension
                    $id = ''
                    $name = $_.BaseName
                } 
                else {
                    $found = $false
                    $content | ForEach-Object {
                        if (-not $found) {
                            $line = $_.Trim()
                            $idx = $line.IndexOf(' ')
                            if ($idx -lt 0) {
                                $type = $line
                            }
                            else {
                                $type = $line.SubString(0,$idx).ToLowerInvariant()
                            }
                            if ($types.Contains($type)) {
                                $found = $true
                            }
                        } 
                    }
    
                    if ($type -eq "dotnet") {
                        $id = ''
                        $name = $_.BaseName
                    }
                    else {
                        $line = $line.SubString($type.Length).TrimStart()
                        if ($type -eq "profile") {
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
                    $filename = $alFileStructure.Invoke($type, $id, $name)
                }
                else {
                    $filename = $alFileStructure.Invoke($type, $id, $name, [ref] $content)
                }
    
                if ($filename) {
                    $filename = $filename.Replace('/','').Replace(':','')
                    $destFileName = Join-Path $Destination $filename
                    $destPath = $destFileName.Substring(0,$destFileName.LastIndexOf('\'))
                    if (-not (Test-Path $destPath)) {
                        New-Item $destPath -ItemType Directory | Out-Null
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
                                        $layoutFilename = $alFileStructure.Invoke($layoutFile.Extension, $id, $name)
                                    }
                                    else {
                                        $layoutFilename = $alFileStructure.Invoke($layoutFile.Extension, $id, $name, [ref] $content)
                                    }
        
                                    $layoutFilename = $layoutFilename.Replace('/','').Replace(':','')
                                    $layoutDestFilename = Join-Path $Destination $layoutFilename
                                    $layoutDestPath = $layoutDestFilename.Substring(0,$layoutDestFilename.LastIndexOfAny(@('\','/')))
                                    if (-not (Test-Path $layoutDestPath)) {
                                        New-Item $layoutDestPath -ItemType Directory | Out-Null
                                    }
                                    [System.IO.File]::WriteAllBytes($layoutDestFilename, $layoutcontent)
        
                                    $content[$_] = $line.SubString(0,$startIdx) + $layoutFilename.Replace('\','/') + $line.SubString($endIdx)
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
                throw "Unexpected error while handling $filename"
            }
        }
    }
    else {
        Copy-Item -Path $Path -Destination $Destination -Recurse:$Recurse -Force | Out-Null
    }
}
Export-ModuleMember -Function Copy-AlSourceFiles
