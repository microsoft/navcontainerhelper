<# 
 .Synopsis
  Convert txt and delta files to AL
 .Description
  Convert objects in myDeltaFolder to AL. Page and Table extensions are created as new objects using the startId as object Id offset.
  Code modifications and other things not supported in extensions will not be converted to AL.
  Manual modifications are required after the conversion.
 .Parameter containerName
  Name of the container in which the txt2al tool will be executed
 .Parameter myDeltaFolder
  Folder containing delta files
 .Parameter myAlFolder
  Folder in which the AL files are created
 .Parameter startId
  Starting offset for objects created by the tool (table and page extensions)
 .Example
  Convert-Txt2Al -containerName test -mydeltaFolder c:\programdata\navcontainerhelper\mydeltafiles -myAlFolder c:\programdata\navcontainerhelper\myAlFiles -startId 50100
#>
function Convert-Txt2Al {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$myDeltaFolder, 
        [Parameter(Mandatory=$true)]
        [string]$myAlFolder, 
        [int]$startId=50100
    )

    $containerMyDeltaFolder = Get-NavContainerPath -containerName $containerName -path $myDeltaFolder -throw
    $containerMyAlFolder = Get-NavContainerPath -containerName $containerName -path $myAlFolder -throw

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($myDeltaFolder, $myAlFolder, $startId)

        if (!($txt2al)) {
            throw "You cannot run Convert-Txt2Al on this Nav Container"
        }
        Write-Host "Converting files in $myDeltaFolder to .al files in $myAlFolder with startId $startId (container paths)"
        Remove-Item -Path $myAlFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myAlFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        Start-Process -FilePath $txt2al -ArgumentList "--source=""$myDeltaFolder"" --target=""$myAlFolder"" --rename --extensionStartId=$startId" -Wait -NoNewWindow
    
    } -ArgumentList $containerMyDeltaFolder, $containerMyAlFolder, $startId
}
Export-ModuleMember -function Convert-Txt2Al
