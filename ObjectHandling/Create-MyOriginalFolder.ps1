<# 
 .Synopsis
  Creates a folder with modified base objects
 .Description
  Compares files from the modifiedFolder with files in the originalFolder to identify which base objects have been changed.
  All changed base objects are copied to the myoriginalFolder, which allows the Create-MyDeltaFolder to identify new and modified objects.
 .Parameter $originalFolder, 
  Folder containig the original base objects
 .Parameter $modifiedFolder, 
  Folder containing your modified objects
 .Parameter $myoriginalFolder
  Folder in which the original objects for your modified objects are copied to
 .Example
  Create-MyOriginalFolder -originalFolder c:\programdata\navcontainerhelper\baseobjects -modifiedFolder c:\programdata\navcontainerhelper\myobjects -myoriginalFolder c:\programdata\navcontainerhelper\mybaseobjects
#>
function Create-MyOriginalFolder {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$originalFolder, 
        [Parameter(Mandatory=$true)]
        [string]$modifiedFolder, 
        [Parameter(Mandatory=$true)]
        [string]$myoriginalFolder
    )

    Write-Host "Copy original objects to $myoriginalFolder for all objects that are modified (container path)"
    if (Test-Path $myoriginalFolder -PathType Container) {
        Get-ChildItem -Path $myoriginalFolder -Include * | Remove-Item -Recurse -Force
    } else {
        New-Item -Path $myoriginalFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
    }        
    Get-ChildItem $modifiedFolder | ForEach-Object {
        $Name = ($_.BaseName+".txt")
        $OrgName = Join-Path $myOriginalFolder $Name
        $TxtFile = Join-Path $originalFolder $Name
        if (Test-Path -Path $TxtFile) {
            Copy-Item -Path $TxtFile -Destination $OrgName
        }
    }
}
Export-ModuleMember -function Create-MyOriginalFolder
