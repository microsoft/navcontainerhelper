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
    $version, $url = GetLatestAlLanguageExtensionVersionAndUrl -allowPrerelease:$allowPrerelease
    return $url
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
