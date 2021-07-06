<# 
 .Synopsis
  Adds GIT to an Al Project Folder
 .Description
  This function will create a .gitignore file, initialize a git repo, add and commit all files in the folder
  The GIT repo will NOT have any remote defined
 .Parameter alProjectFolder
  Path of the folder in which to add a GIT repo
 .Parameter commitMessage
  Message of initial commit to the repo
 .Example
  Add-GitToAlProjectFolder
#>
function Add-GitToAlProjectFolder {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $alProjectFolder,
        [Parameter(Mandatory=$true)]
        [string] $commitMessage
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    Write-Host "Initializing Git repository"

    $gitIgnoreFile = Join-Path $AlProjectFolder ".gitignore"
    Set-Content -Path $gitIgnoreFile -Value ".vscode`r`n*.app"

    $oldLocation = Get-Location
    Set-Location $AlProjectFolder
    & git init
    Write-Host "Adding files"
    & git add .
    & git gc --quiet
    Write-Host "Committing files"
    & git commit -m $commitMessage --quiet
    Set-Location $oldLocation
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Add-GitToAlProjectFolder
