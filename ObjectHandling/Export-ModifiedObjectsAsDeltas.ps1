<# 
 .Synopsis
  Export modified objects in a Nav container as DELTA files
 .Description
  This command will invoke the 3 commands in order to export modified objects and convert them to DELTA files:
  1. Export-NavContainerObjects
  2. Create-MyOriginalFolder
  3. Create-MyDeltaFolder
  A folder with the name of the container is created underneath c:\demo\extensions for holding all the temp and the final output.
  The command will open a windows explorer window with the output
 .Parameter containerName
  Name of the container for which you want to export and convert objects
 .Parameter vmadminUsername
  Username of the administrator user in the container (defaults to sa)
 .Parameter adminPassword
  The admin password for the container (if using NavUserPassword authentication)
 .Parameter startId
  Starting offset for objects created by the tool (table and page extensions)
 .Parameter openFolder
  Switch telling the function to open the result folder in Windows Explorer when done
 .Example
  Export-ModifiedObjectsAsDeltas -containerName test
 .Example
  Export-ModifiedObjectsAsDeltas -containerName test -adminPassword <adminPassword>
#>
function Export-ModifiedObjectsAsDeltas {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$vmadminUsername = 'sa',
        [SecureString]$adminPassword = $null, 
        [switch]$useNewSyntax = $false,
        [switch]$openFolder = $true
    )

    $containerAuth = Get-NavContainerAuth -containerName $containerName
    if ($containerAuth -eq "NavUserPassword" -and !($adminPassword)) {
        $adminPassword = Get-DefaultAdminPassword
    }

    if ((Get-NavContainerSharedFolders -containerName $containerName)[$demoFolder] -ne $containerDemoFolder) {
        throw "In order to run Export-ModifiedObjectsAsDeltas you need to have shared $demoFolder to $containerDemoFolder in the container (docker run ... -v ${demoFolder}:$containerDemoFolder ... <image>)."
    }

    $suffix = ""
    if ($useNewSyntax) {
        $suffix = "-newsyntax"
    }
    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $originalFolder   = Join-Path $ExtensionsFolder "Original-$navversion$suffix"

    if (!(Test-Path $originalFolder)) {
        throw "Folder $originalFolder must contain all Nav base objects (original). You can use Export-NavContainerObjects on a fresh container or create your development container using New-CSideDevContainer, which does this automatically."
    }

    $modifiedFolder   = Join-Path $ExtensionsFolder "$containerName\modified$suffix"
    $myOriginalFolder = Join-Path $ExtensionsFolder "$containerName\original$suffix"
    $myDeltaFolder    = Join-Path $ExtensionsFolder "$containerName\delta$suffix"

    # Export my objects
    Export-NavContainerObjects -containerName $containerName `
                               -objectsFolder $modifiedFolder `
                               -filter "modified=Yes" `
                               -vmadminUsername $vmadminUsername `
                               -adminPassword $adminPassword `
                               -exportToNewSyntax:$useNewSyntax

    Create-MyOriginalFolder -originalFolder $originalFolder `
                            -modifiedFolder $modifiedFolder `
                            -myOriginalFolder $myOriginalFolder

    Create-MyDeltaFolder -containerName $containerName `
                         -modifiedFolder $modifiedFolder `
                         -myOriginalFolder $myOriginalFolder `
                         -myDeltaFolder $myDeltaFolder

    if ($openFolder) {
        Start-Process $myDeltaFolder
        Write-Host "delta files created in $myDeltaFolder"
    }
}
Export-ModuleMember -Function Export-ModifiedObjectsAsDeltas
