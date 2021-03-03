<# 
 .Synopsis
  Function for resolving dependencies using an AzureFeed
 .Description
  Function for resolving dependencies using an AzureFeed
  To being able to resolve dependencies an artifact must be in the following format.
  The app id must be in the artifact name so apps will be identified correctly.
  The artifact can contain an .runtime.app file. If no app.json or .app file is present the .runtime.app fill be treated as a leaf in the tree.
  If an app.json is present dependencies will be take from that file.
  If no app.json but an .app file is present that will be extracted and used to find dependencies. 
#>
function Resolve-DependenciesFromAzureFeed.ps1 {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $path
    )
}
Export-ModuleMember -Function Resolve-DependenciesFromAzureFeed.ps1
