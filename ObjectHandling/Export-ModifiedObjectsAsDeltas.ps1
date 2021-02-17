<# 
 .Synopsis
  Export modified objects in a Nav container as DELTA files
 .Description
  This command will invoke the 3 commands in order to export modified objects and convert them to DELTA files:
  1. Export-NavContainerObjects
  2. Create-MyOriginalFolder
  3. Create-MyDeltaFolder
  A folder with the name of the container is created underneath c:\programdata\bccontainerhelper\extensions for holding all the temp and the final output.
  The command will open a windows explorer window with the output
 .Parameter containerName
  Name of the container for which you want to export and convert objects
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter useNewSyntax
  Include the useNewSyntax switch to use new syntax
 .Parameter filter
  Filter specifying the objects you want to export (default is modified=1)
 .Parameter deltaFolder
  Path of a folder in which you want to receive the delta files (optional)
 .Parameter fullObjectsFolder
  Path of a folder in which you want to receive the object files (optional)
 .Parameter openFolder
  Switch telling the function to open the result folder in Windows Explorer when done
 .Example
  Export-ModifiedObjectsAsDeltas -containerName test
 .Example
  Export-ModifiedObjectsAsDeltas -containerName test -sqlCredential <sqlCredential>
#>
function Export-ModifiedObjectsAsDeltas {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [PSCredential] $sqlCredential = $null,
        [switch] $useNewSyntax,
        [string] $filter = "Modified=1",
        [string] $deltaFolder = "",
        [string] $fullObjectsFolder = "",
        [switch] $openFolder,
        [string] $originalFolder = ""
    )

    AssumeNavContainer -containerOrImageName $containerName -functionName $MyInvocation.MyCommand.Name

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential -doNotAskForCredential

    if ((Get-NavContainerSharedFolders -containerName $containerName)[$hostHelperFolder] -ne $containerHelperFolder) {
        throw "In order to run Export-ModifiedObjectsAsDeltas you need to have shared $hostHelperFolder to $containerHelperFolder in the container (docker run ... -v ${hostHelperFolder}:$containerHelperFolder ... <image>)."
    }

    $suffix = ""
    $exportTo = "txt folder"
    if ($useNewSyntax) {
        $suffix = "-newsyntax"
        $exportTo = 'txt folder (new syntax)'
    }
    if (!$originalFolder) {
      $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
      $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"
    }
    
    if (!(Test-Path $originalFolder)) {
        throw "Folder $originalFolder must contain all Nav base objects (original). You can use Export-NavContainerObjects on a fresh container or create your development container using New-CSideDevContainer, which does this automatically."
    }

    $modifiedFolder   = Join-Path $ExtensionsFolder "$containerName\modified$suffix"
    $myOriginalFolder = Join-Path $ExtensionsFolder "$containerName\original$suffix"
    $myDeltaFolder    = Join-Path $ExtensionsFolder "$containerName\delta$suffix"

    # Export my objects
    Export-NavContainerObjects -containerName $containerName `
                               -objectsFolder $modifiedFolder `
                               -filter $filter `
                               -sqlCredential $sqlCredential `
                               -exportTo $exportTo

    # Remove [LineStart()] Properties
    Get-ChildItem -path $modifiedFolder -filter "*.txt" -recurse | % {
        Set-Content -Path $_.FullName -Value (Get-Content -Path $_.FullName | Where-Object { !($_.Trim().Startswith('[LineStart(') -and $_.Trim().Endswith(')]')) })
    }

    Create-MyOriginalFolder -originalFolder $originalFolder `
                            -modifiedFolder $modifiedFolder `
                            -myOriginalFolder $myOriginalFolder

    Create-MyDeltaFolder -containerName $containerName `
                         -modifiedFolder $modifiedFolder `
                         -myOriginalFolder $myOriginalFolder `
                         -myDeltaFolder $myDeltaFolder `
                         -useNewSyntax:$useNewSyntax

    if ($openFolder) {
        Start-Process $myDeltaFolder
        Write-Host "delta files created in $myDeltaFolder"
    }

    if ($deltaFolder) {
        Remove-Item -Path "$deltaFolder\*.txt" -Force
        Remove-Item -Path "$deltaFolder\*.delta" -Force
        Copy-Item -Path "$myDeltaFolder\*.txt" -Destination $deltaFolder
        Copy-Item -Path "$myDeltaFolder\*.delta" -Destination $deltaFolder
    }

    if ($fullObjectsFolder) {
        Remove-Item -Path "$fullObjectsFolder\*.txt" -Force
        Copy-Item -Path "$modifiedFolder\*.txt" -Destination $fullObjectsFolder
    }
}
Export-ModuleMember -Function Export-ModifiedObjectsAsDeltas
