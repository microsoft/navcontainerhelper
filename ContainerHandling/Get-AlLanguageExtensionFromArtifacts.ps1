<# 
 .Synopsis
  Get the path of the AL Language Extension from an artifactUrl
 .Description
  Downloads artifacts and return the path of the .vsix file within the artifacts
 .Example
  New-BcContainer ... -vsixFile (Get-AlLanguageExtensionFromArtifacts -artifactUrl $artifactUrl) ...
#>
function Get-AlLanguageExtensionFromArtifacts {
    Param(
        [string] $artifactUrl
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $paths = Download-Artifacts $artifactUrl -includePlatform
    $vsixFile = Get-Item -Path (Join-Path $paths[1] "ModernDev\*\Microsoft Dynamics NAV\*\AL Development Environment\*.vsix")
    if ($vsixFile) {
        $vsixFile.FullName
    }
    else {
        throw "Unable to locate AL Language Extension from artifacts $($artifactUrl.Split('?')[0])"
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
Export-ModuleMember -Function Get-AlLanguageExtensionFromArtifacts
