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
        [Parameter(Mandatory=$true)]
        [string] $appFile
    )
    $appJson = RunAlTool -arguments @('GetPackageManifest', """$appFile""")
    if (!($appJson.PSObject.Properties.Name -eq "description")) { Add-Member -InputObject $appJson -MemberType NoteProperty -Name "description" -Value "" }
    if (!($appJson.PSObject.Properties.Name -eq "dependencies")) { Add-Member -InputObject $appJson -MemberType NoteProperty -Name "dependencies" -Value @() }
    return $appJson
}
Export-ModuleMember -Function Get-AppJsonFromAppFile
