<# 
 .Synopsis
  Extract the app.json file from an app (also from runtime packages)
 .Description
 .Parameter AppFile
  Path of the application file from which to extract the app.json
 .Example
  Get-AppJsonFromAppFile -appFile c:\temp\baseapp.app
#>
function Get-AppJsonFromAppFile {
    Param(
        [string] $appFile
    )
    # ALTOOL is at the moment only available in prerelease        
    $path = DownloadLatestAlLanguageExtension -allowPrerelease
    if ($isLinux) {
        $alToolExe = Join-Path $path 'extension/bin/linux/altool'
        Write-Host "Setting execute permissions on altool"
        & /usr/bin/env sudo pwsh -command "& chmod +x $alToolExe"
    }
    else {
        $alToolExe = Join-Path $path 'extension/bin/win32/altool.exe'
    }
    $appJson = CmdDo -Command $alToolExe -arguments @('GetPackageManifest', """$appFile""") -returnValue -silent | ConvertFrom-Json
    if (!($appJson.PSObject.Properties.Name -eq "description")) { Add-Member -InputObject $appJson -MemberType NoteProperty -Name "description" -Value "" }
    if (!($appJson.PSObject.Properties.Name -eq "dependencies")) { Add-Member -InputObject $appJson -MemberType NoteProperty -Name "dependencies" -Value @() }
    return $appJson
}
Export-ModuleMember -Function Get-AppJsonFromAppFile
