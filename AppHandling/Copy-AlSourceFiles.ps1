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
        $types = @('page', 'table', 'codeunit', 'report', 'query', 'xmlport', 'profile', 'dotnet')
        
        Get-ChildItem -Path $Path -Recurse | ForEach-Object {
    
            if (-not $_.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) {
                $filename = $_.Name
                if ($_.Extension -eq '.al') {
                    $cnt = 1
                    $found = $false
                    do {
                        Get-Content -Path $_.FullName -First $cnt | ForEach-Object {
                            if (-not $found) {
                                $line = $_.Trim()
                                $idx = $line.IndexOf(' ')
                                if ($idx -lt 0) {
                                    $type = $line
                                }
                                else {
                                    $type = $line.SubString(0,$idx)
                                }
                                if ($types.Contains($type)) {
                                    $found = $true
                                }
                            } 
                        }
                        $cnt += $cnt
                    } while (-not $found)

                    if ($type -eq "dotnet") {
                        $id = ''
                        $name = 'dotnet'
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
                            $name = $line.SubString(1,$line.Length-2)
                        }
                        else {
                            $name = $line
                        }
                    }
                    $filename = Invoke-Command -ScriptBlock $alFileStructure -ArgumentList $type, $id, $name
                }
                else {
                    $filename = Invoke-Command -ScriptBlock $alFileStructure -ArgumentList $_.Extension, '', $_.BaseName
                }
                $filename = $filename.Replace('/','').Replace(':','')
                $destFileName = Join-Path $Destination $filename
                $destPath = $destFileName.Substring(0,$destFileName.LastIndexOf('\'))
                if (-not (Test-Path $destPath)) {
                    New-Item $destPath -ItemType Directory | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $destFileName -Force
            }
        }
    }
    else {
        Copy-Item -Path $Path -Destination $Destination -Recurse:$Recurse -Force | Out-Null
    }
}
Export-ModuleMember -Function Copy-AlSourceFiles
