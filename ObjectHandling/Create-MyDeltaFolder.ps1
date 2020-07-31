<# 
 .Synopsis
  Create folder with delta files for my objects
 .Description
  Compare my objects with my base objects and create a folder with delta files.
  Modified objects will be stored as .delta files, new objects will be .txt files.
 .Parameter containerName
  Name of the container in which the Nav Development Cmdlets are to be executed
 .Parameter modifiedFolder
  Folder containing your modified objects
 .Parameter myoriginalFolder
  Folder containing the original objects for your modified objects
 .Parameter myDeltaFolder
  Folder in which the delta files are created
 .Parameter useNewSyntax
  Include the useNewSyntax switch to use new syntax
 .Example
  Create-MyDeltaFolder -containerName test -modifiedFolder c:\programdata\bccontainerhelper\myobjects -myoriginalFolder c:\programdata\bccontainerhelper\myoriginalobjects -mydeltaFolder c:\programdata\bccontainerhelper\mydeltafiles
#>
function Create-MyDeltaFolder {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $modifiedFolder, 
        [Parameter(Mandatory=$true)]
        [string] $myOriginalFolder, 
        [Parameter(Mandatory=$true)]
        [string] $myDeltaFolder,
        [switch] $useNewSyntax
    )

    AssumeNavContainer -containerOrImageName $containerName -functionName $MyInvocation.MyCommand.Name

    $containerModifiedFolder = Get-NavContainerPath -containerName $containerName -path $modifiedFolder -throw
    $containerMyOriginalFolder = Get-NavContainerPath -containerName $containerName -path $myOriginalFolder -throw
    $containerMyDeltaFolder = Get-NavContainerPath -containerName $containerName -path $myDeltaFolder -throw

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($modifiedFolder, $myOriginalFolder, $myDeltaFolder, $useNewSyntax)

        Write-Host "Compare modified objects with original objects in $myOriginalFolder and create Deltas in $myDeltaFolder (container paths)"
        if (Test-Path $myDeltaFolder -PathType Container) {
            Get-ChildItem -Path $myDeltaFolder -Include * | Remove-Item -Recurse -Force
        } else {
            New-Item -Path $myDeltaFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
        }
        $params = @{}
        if ($useNewSyntax) {
            $params += @{ 'ExportToNewSyntax' = $true }
        }

        if ([System.Text.Encoding]::Default.BodyName -eq "utf-8") {
            $cp = (Get-Culture).TextInfo.OEMCodePage
            $encoding = [System.Text.Encoding]::GetEncoding($cp)
            
            Write-Host "Converting my modified objects from OEM($cp) to UTF8 before comparing"
            Get-ChildItem -Path (Join-Path $modifiedFolder "*.*") | ForEach-Object {
                $content = [System.IO.File]::ReadAllText($_.FullName, $encoding )
                [System.IO.File]::WriteAllText($_.FullName, $content, [System.Text.Encoding]::UTF8 )
            }
        }

        Compare-NAVApplicationObject @params -OriginalPath $myOriginalFolder -ModifiedPath $modifiedFolder -DeltaPath $myDeltaFolder | Out-Null

        if ([System.Text.Encoding]::Default.BodyName -eq "utf-8") {
            Write-Host "Converting files from UTF8 to OEM($cp) after comparing"
            
            $myDeltaFolder, $modifiedFolder | % {
                Get-ChildItem -Path (Join-Path $_ "*.*") | ForEach-Object {
                    $content = [System.IO.File]::ReadAllText($_.FullName,[System.Text.Encoding]::UTF8 )
                    [System.IO.File]::WriteAllText($_.FullName, $content, $encoding )
                }
            }
        }


        Write-Host "Rename new objects to .TXT"
        Get-ChildItem $myDeltaFolder | ForEach-Object {
            $Name = $_.Name
            if ($Name.ToLowerInvariant().EndsWith(".delta")) {
                $BaseName = $_.BaseName
                $OrgName = Join-Path $myOriginalFolder "${BaseName}.TXT"
                if (!(Test-Path -Path $OrgName)) {
                    Rename-Item -Path $_.FullName -NewName "${BaseName}.TXT"
                }
            }
        }
    } -ArgumentList $containerModifiedFolder, $containerMyOriginalFolder, $containerMyDeltaFolder, $useNewSyntax
}
Export-ModuleMember -Function Create-MyDeltaFolder
