<#
 .SYNOPSIS
  Copy file from Cloud BC Container
 .DESCRIPTION
  Copy file from Cloud BC Container
 .PARAMETER authContext
 Authorization Context for Cloud BC Container Provider
 .PARAMETER containerId
  Container Id of the Cloud BC Container to copy file from
 .PARAMETER containerPath
  Path to the file in the container (from)
 .PARAMETER localPath
  Path to the local file (to)
 .EXAMPLE
  Copy-FileFromAlpacaBcContainer -authContext $authContext -containerId $containerId -containerPath 'c:\run\navstart.ps1' -localPath 'c:\temp\navstart.ps1'
#>
function Copy-FileFromCloudBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [string] $containerPath,
        [string] $localPath
    )

    $authContext = Renew-BcAuthContext -bcAuthContext $authContext

    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        # If the container is an Alpaca container, we can use the Alpaca function and remove the alias
        # not yet implemented
    }

    # If no specific Cloud container provider is specified, use the default method (invoke-script)
    $content = Invoke-ScriptInCloudBcContainer -authContext $authContext -containerId $containerId -scriptblock { Param($containerPath)
        [System.IO.File]::ReadAllBytes($containerPath)
    } -argumentList $containerPath
    [System.IO.File]::WriteAllBytes($localPath, $content)
}
Set-Alias -Name Copy-FileFromAlpacaBcContainer -Value Copy-FileFromCloudBcContainer
Export-ModuleMember -Function Copy-FileFromCloudBcContainer -Alias Copy-FileFromAlpacaBcContainer
