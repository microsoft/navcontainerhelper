<#
 .SYNOPSIS
 .DESCRIPTION
 .PARAMETER compilerFolder
 .EXAMPLE
#>
function Remove-BcCompilerFolder {
    Param(
        [string] $compilerFolder
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    if ($compilerFolder -like (Join-Path $bcContainerHelperConfig.hostHelperFolder "compiler\*")) {
        Remove-Item -Path $compilerFolder -Force -Recurse -ErrorAction Ignore
    }
    else {
        throw "$compilerFolder is not a ContainerHelper Compiler Folder"
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
Export-ModuleMember -Function Remove-BcCompilerFolder