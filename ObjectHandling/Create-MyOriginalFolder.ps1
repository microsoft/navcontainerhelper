<# 
 .Synopsis
  Creates a folder with modified base objects
 .Description
  Compares files from the modifiedFolder with files in the originalFolder to identify which base objects have been changed.
  All changed base objects are copied to the myoriginalFolder, which allows the Create-MyDeltaFolder to identify new and modified objects.
 .Parameter originalFolder
  Folder containig the original base objects
 .Parameter modifiedFolder
  Folder containing your modified objects
 .Parameter myoriginalFolder
  Folder in which the original objects for your modified objects are copied to
 .Example
  Create-MyOriginalFolder -originalFolder c:\programdata\bccontainerhelper\baseobjects -modifiedFolder c:\programdata\bccontainerhelper\myobjects -myoriginalFolder c:\programdata\bccontainerhelper\mybaseobjects
#>
function Create-MyOriginalFolder {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $originalFolder, 
        [Parameter(Mandatory=$true)]
        [string] $modifiedFolder, 
        [Parameter(Mandatory=$true)]
        [string] $myoriginalFolder
    )

    AssumeNavContainer -containerOrImageName $containerName -functionName $MyInvocation.MyCommand.Name

    $containerOriginalFolder = Get-NavContainerPath -containerName $containerName -path $originalFolder -throw
    $containerModifiedFolder = Get-NavContainerPath -containerName $containerName -path $modifiedFolder -throw
    $containerMyOriginalFolder = Get-NavContainerPath -containerName $containerName -path $myOriginalFolder -throw

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($originalFolder, $modifiedFolder, $myOriginalFolder)
    
        Write-Host "Copy original objects to $myoriginalFolder for all objects that are modified (container path)"
        if (Test-Path $myoriginalFolder -PathType Container) {
            Get-ChildItem -Path $myoriginalFolder -Include * | Remove-Item -Recurse -Force
        } else {
            New-Item -Path $myoriginalFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
        }
    
        # If we are running a hyperv container we need to write the files in UTF8 (for compare)
        $cp = (Get-Culture).TextInfo.OEMCodePage
        $encoding = [System.Text.Encoding]::GetEncoding($cp)
        if ([System.Text.Encoding]::Default.BodyName -eq "utf-8") {
            $dstenc = [System.Text.Encoding]::UTF8
            Write-Host "Use UTF8"
        }
        else {
            $dstenc = $encoding
        }
    
        Get-ChildItem $modifiedFolder | ForEach-Object {
            $Name = ($_.BaseName+".txt")
            $OrgName = Join-Path $myOriginalFolder $Name
            $TxtFile = Join-Path $originalFolder $Name
            if (Test-Path -Path $TxtFile) {
                # Remove [LineStart()] Properties
                $content = [System.IO.File]::ReadAllLines($TxtFile, $encoding) | Where-Object { !($_.Trim().Startswith('[LineStart(') -and $_.Trim().Endswith(')]')) }
                [System.IO.File]::WriteAllLines($OrgName, $content, $dstenc)
            }
        }
    } -argumentList $containerOriginalFolder, $containerModifiedFolder, $containerMyOriginalFolder
}
Export-ModuleMember -Function Create-MyOriginalFolder
