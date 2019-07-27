Describe 'ObjectHandling' {

    $objectsTxtFile = Join-Path $PSScriptRoot "ObjectHandling-objects.txt"
    $deltaFolder = Join-Path $PSScriptRoot "delta"
    $myDeltaFolder = Join-Path $navMyPath "delta"
    $myObjectsFolder = Join-Path $navMyPath "objects"
    $objectsFobFile = Join-Path $myObjectsFolder "objects.fob"

    It 'Import-ObjectsToNavContainer (.txt)' {
        Import-ObjectsToNavContainer -containerName $navContainerName `
                                     -objectsFile $objectsTxtFile
    }
    It 'Compile-ObjectsInNavContainer' {
        Compile-ObjectsInNavContainer -containerName $navContainerName
    }
    It 'Export-NavContainerObjects' {
        Export-NavContainerObjects -containerName $navContainerName `
                                   -exportTo 'fob file' `
                                   -objectsFolder $myObjectsFolder `
                                   -filter "Modified=Yes"
        $objectsFobFile | Should -Exist
    }
    It 'Import-ObjectsToNavContainer (.fob)' {
        Import-ObjectsToNavContainer -containerName $navContainerName `
                                     -objectsFile $objectsFobFile
    }
    It 'Convert-ModifiedObjectsToAl' {
        Convert-ModifiedObjectsToAl -containerName $navContainerName `
                                    -startId 50100
        $alFiles = Get-ChildItem -Path (Join-Path $navContainerPath "al-newsyntax")
        $alFiles.Count | Should -Be 2
    }
    It 'Convert-Txt2Al' {
    }
    It 'Create-MyDeltaFolder' {
    }
    It 'Create-MyOriginalFolder' {
    }
    It 'Export-ModifiedObjectsAsDeltas' {
    }
    It 'Import-DeltasToNavContainer' {
        #TODO
    }
    It 'Import-TestToolkitToNavContainer' {
    }
    It 'Invoke-NavContainerCodeunit' {
        #TODO
    }

    # Recreate contaminated containers
    #. (Join-Path $PSScriptRoot '_CreateNavContainer.ps1')

}
