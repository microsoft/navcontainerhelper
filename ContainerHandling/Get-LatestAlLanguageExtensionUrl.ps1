<# 
 .Synopsis
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Description
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Parameter allowPrerelease
  If specified, will return the URL of the latest version (including pre-release versions) of the AL Language Extension
 .Example
  New-BcContainer ... -vsixFile (Get-LatestAlLanguageExtensionUrl) ...
 .Example
  Download-File -SourceUrl (Get-LatestAlLanguageExtensionUrl) -DestinationFile "c:\temp\al.vsix"
#>
function Get-LatestAlLanguageExtensionUrl {
    Param(
        [switch] $allowPrerelease
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $listing = Invoke-WebRequest -Method POST -UseBasicParsing `
                      -Uri https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1 `
                      -Body '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":[],"flags":0x192}' `
                      -ContentType application/json | ConvertFrom-Json
    
    $vsixUrl =  $listing.results | Select-Object -First 1 -ExpandProperty extensions `
                         | Select-Object -ExpandProperty versions `
                         | Where-Object { ($allowPrerelease.IsPresent -or !(($_.properties.Key -eq 'Microsoft.VisualStudio.Code.PreRelease') -and ($_.properties | where-object { $_.Key -eq 'Microsoft.VisualStudio.Code.PreRelease' }).value -eq "true")) } `
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
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Get-LatestAlLanguageExtensionUrl
