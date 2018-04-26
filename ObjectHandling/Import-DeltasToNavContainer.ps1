<# 
 .Synopsis
  Merge deltas and import Objects to Nav Container
 .Description
  Create a session to a Nav Container and run Update-NavApplicationObject, 
  merginge deltas with original objects from that container and create object file
  Import object file using Import-NavApplicationObject
 .Parameter containerName
  Name of the container in which you want to import deltas
 .Parameter deltaFolder
  Path of the folder containing the delta files you want to import
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter compile
  Include this switch to compile uncompiled objects after the import
 .Example
  Import-DeltasToNavContainer -containerName test2 -deltaFolder c:\temp\mydeltas
#>
function Import-DeltasToNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$deltaFolder,
        [System.Management.Automation.PSCredential]$sqlCredential = $null,
        [switch]$compile
    )

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential -doNotAskForCredential
    $containerDeltaFolder = Get-NavContainerPath -containerName $containerName -path $deltaFolder
    if ("$containerDeltaFolder" -eq "") {
        throw "The deltaFolder ($deltaFolder) is not shared with the container."
    }

    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion"
    $mergeResultFile  = Join-Path $ExtensionsFolder "$containerName\mergeresult.txt"
    Remove-Item $mergeResultFile -Force -ErrorAction Ignore
    $mergedObjectsFile  = Join-Path $ExtensionsFolder "$containerName\mergedobjects.txt"
    Remove-Item $mergedObjectsFile -Force -ErrorAction Ignore
    $myOriginalFolder = Join-Path $ExtensionsFolder "$containerName\original"
    Remove-Item $myOriginalFolder -Force -Recurse -ErrorAction Ignore

    Create-MyOriginalFolder -originalFolder $originalFolder `
                            -modifiedFolder $deltaFolder `
                            -myOriginalFolder $myOriginalFolder

    $containerMyOriginalFolder = Get-NavContainerPath -containerName $containerName -path $myOriginalFolder -throw
    $containerMergeResultFile = Get-NavContainerPath -containerName $containerName -path $mergeResultFile -throw
    $containerMergedObjectsFile = Get-NavContainerPath -containerName $containerName -path $mergedObjectsFile -throw

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($deltaFolder, $originalFolder, $mergedObjectsFile, $mergeResultFile)
    
        Write-Host "Merging Deltas from $deltaFolder (container path)"
        Update-NAVApplicationObject -TargetPath $originalFolder `
                                    -DeltaPath $deltaFolder `
                                    -ResultPath $mergedObjectsFile `
                                    -ModifiedProperty Yes `
                                    -VersionListProperty FromModified `
                                    -DateTimeProperty FromModified | Set-Content $mergeResultFile

    } -ArgumentList $containerDeltaFolder, $containerMyOriginalFolder, $containerMergedObjectsFile, $containerMergeResultFile

    if (Test-Path $mergedObjectsFile) {
        Import-ObjectsToNavContainer -containerName $containerName `
                                     -objectsFile $mergedObjectsFile `
                                     -sqlcredential $sqlCredential
        if ($compile) {
            Compile-ObjectsInNavContainer -containerName $containerName
        }
    }
}
Export-ModuleMember -Function Import-DeltasToNavContainer
