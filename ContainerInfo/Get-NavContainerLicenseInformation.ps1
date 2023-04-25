<# 
 .Synopsis
  Retrieve the Business Central license information from a NAV/BC Container 
 .Description
  Returns the license information used on the Business Central service in the container.
 .Parameter containerName
  Name of the container for which you want to get the license information
 .Example
  Get-BcContainerLicenseInformation -ContainerName "MyContainer"
#>
Function Get-BcContainerLicenseInformation {
    Param (
        [String] $ContainerName = $bcContainerHelperConfig.defaultContainerName
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock {
        Get-NavServerInstance | Export-NAVServerLicenseInformation
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
Set-Alias -Name Get-NavContainerLicenseInformation -Value Get-BcContainerLicenseInformation
Export-ModuleMember -Function Get-BcContainerLicenseInformation -Alias Get-NavContainerLicenseInformation