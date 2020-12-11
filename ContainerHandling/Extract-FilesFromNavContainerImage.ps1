<# 
 .Synopsis
  Extract Files From NAV/BC Container Image
 .Description
  Extract all files from a Container Image necessary to start a generic container with these files
 .Parameter imageName
  Name of the Container Image from which you want to extract the files
 .Parameter path
  Location where you want the files to be placed
 .Parameter extract
  Determine what you need to extract (default is all)
 .Parameter force
  Specify -force if you want to automatically remove the destination folder if it exists
 .Example
  Extract-FilesFromBcContainerImage -ImageName microsoft/bcsandbox:us -Path "c:\programdata\bccontainerhelper\extensions\acontainer\afolder"
#>
function Extract-FilesFromBcContainerImage {
    [CmdletBinding()]
    Param (
        [string] $imageName,
        [string] $path,
        [ValidateSet('all','vsix','database')]
        [string] $extract = "all",
        [switch] $force
    )

#    $artifactUrl = Get-BcContainerArtifactUrl -containerName $imageName
#    if ($artifactUrl) {
#        throw "Extract-FilesFromBcContainerImage doesn't support images based on artifacts."
#    }

    $ErrorActionPreference = 'Continue'

    Write-Host "Creating temp container from $imagename and extract necessary files"
    $containerName = "bccontainerhelper-temp"
    docker rm $containerName 2>$null | Out-null
    docker create --name $containerName $imagename | Out-Null

    $ErrorActionPreference = 'Stop'

    Extract-FilesFromStoppedBcContainer -containerName $containerName -path $path -extract $extract -force:$force
    
    $ErrorActionPreference = 'Continue'

    Write-Host "Removing temp container"
    docker rm $containerName 2>$null | Out-null

    $ErrorActionPreference = 'Stop'
}
Set-Alias -Name Extract-FilesFromNavContainerImage -Value Extract-FilesFromBcContainerImage
Export-ModuleMember -Function Extract-FilesFromBcContainerImage -Alias Extract-FilesFromNavContainerImage
