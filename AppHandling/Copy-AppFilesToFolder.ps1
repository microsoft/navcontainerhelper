<# 
 .Synopsis
  Copy App Files to Folder (supporting urls, .zip files and .app files)
 .Description
 .Parameter appFiles
  Can be an array of appfiles, urls or zip files
 .Parameter folder
  Folder to copy the app files to
 .Example
  Copy-AppFilesToFolder -appFiles @("c:\temp\apps.zip", "c:\temp\app2.app", "https://github.com/org/repo/releases/download/2.0.200/project-branch-Apps-1.0.0.0.zip") -folder "c:\temp\appfiles"
#>
function Copy-AppFilesToFolder {
    Param(
        $appFiles,
        [string] $folder
    )

    CopyAppFilesToFolder -appFiles $appFiles -folder $folder
}
Export-ModuleMember -Function Copy-AppFilesToFolder
