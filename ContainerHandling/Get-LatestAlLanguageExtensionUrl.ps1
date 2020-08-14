<# 
 .Synopsis
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Description
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the legal link
 .Example
  New-BcContainer ... -vsixFile (Get-LatestAlLanguageExtensionUrl) ...
 .Example
  Download-File -SourceUrl (Get-LatestAlLanguageExtensionUrl) -DestinationFile "c:\temp\al.vsix"
#>
function Get-LatestAlLanguageExtensionUrl {
    $listing = Invoke-WebRequest -Method POST -UseBasicParsing `
                      -Uri https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1 `
                      -Body '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":[],"flags":914}' `
                      -ContentType application/json | ConvertFrom-Json 
     
    $vsixUrl = $listing.results | Select-Object -First 1 -ExpandProperty extensions `
                         | Select-Object -First 1 -ExpandProperty versions `
                         | Select-Object -First 1 -ExpandProperty files `
                         | Where-Object { $_.assetType -eq "Microsoft.VisualStudio.Services.VSIXPackage"} `
                         | Select-Object -ExpandProperty source
     
    if ($vsixUrl) {
        $vsixUrl
    }
    else {
        throw "Unable to locate latest AL Language Extension from the VS Code Marketplace"
    }
}
Export-ModuleMember -Function Get-LatestAlLanguageExtensionUrl
