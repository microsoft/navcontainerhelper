<# 
 .Synopsis
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Description
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Parameter includePreRelease
  Allow pre-release versions of the AL Language Extension
 .Example
  New-BcContainer ... -vsixFile (Get-LatestAlLanguageExtensionUrl) ...
 .Example
  Download-File -SourceUrl (Get-LatestAlLanguageExtensionUrl) -DestinationFile "c:\temp\al.vsix"
#>
function Get-LatestAlLanguageExtensionUrl {
    [CmdletBinding()]
    Param (
        [switch] $includePreRelease
    )

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $listing = Invoke-WebRequest -Method POST -UseBasicParsing `
            -Uri https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1 `
            -Body '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":[],"flags":55}' `
            -ContentType application/json | ConvertFrom-Json 

        $vsixUrl = $listing.results | Select-Object -First 1 -ExpandProperty extensions `
        | Select-Object -First 1 -ExpandProperty versions `
        | Where-Object { $includePreRelease.IsPresent -or ($_.properties.value[$_.properties.key.IndexOf("Microsoft.VisualStudio.Code.PreRelease")] -ne $true) } `
        | Select-Object -First 1 -ExpandProperty files `
        | Where-Object { $_.assetType -eq "Microsoft.VisualStudio.Services.VSIXPackage" } `
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
