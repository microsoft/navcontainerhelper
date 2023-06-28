<#
.SYNOPSIS
 Copy file to Cloud BC Container
.DESCRIPTION
 Copy file to Cloud BC Container
.PARAMETER authContext
 Authorization Context for Cloud BC Container Provider
.PARAMETER containerId
 Container Id of the Cloud BC Container to copy file to
.PARAMETER containerPath
 Path to the file in the container (to)
.PARAMETER localPath
 Path to the local file (from)
.EXAMPLE
 Copy-FileToCloudBcContainer -authContext $authContext -containerId $containerId -containerPath 'c:\dl\myapp.app' -localPath 'c:\temp\myapp.app'
#>
function Copy-FileToCloudBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [string] $localPath,
        [string] $containerPath
    )
    
    $authContext = Renew-BcAuthContext -bcAuthContext $authContext

    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        # If the container is an Alpaca container, we can use the Alpaca function and remove the alias
        # not yet implemented
    }

    # If no specific Cloud container provider is specified, use the default method (invoke-script)
    $content = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($localPath))
    $blockSize = 8192
    $idx = 0
    Write-Host -noNewLine "Copying $([System.IO.Path]::GetFileName($localPath)) to Alpaca container $containerId"
    While ($content.Length -gt $idx) {
        Write-Host -noNewLine "."
        $thisBlockSize = $blockSize
        if ($idx+$thisBlockSize -gt $content.Length) { $thisBlockSize = $content.Length - $idx }
        $block = $content.Substring($idx, $thisBlockSize)
        Invoke-ScriptInCloudBcContainer -authContext $authContext -containerId $containerId -scriptblock { Param([string] $containerPath, [string] $block, [bool] $first, [bool]  $last)
            if ($first) {
                $directoryName = [System.IO.Path]::GetDirectoryName($containerPath)
                if (!(Test-Path -Path $directoryName)) {
                    New-Item -Path $directoryName -ItemType Directory | Out-Null
                }
                if (Test-Path -Path $containerPath) {
                    Remove-Item -Path $containerPath -force | Out-Null
                }
            }
            Add-Content -Path $containerPath -Value $block -Encoding UTF8 -Force | Out-Null
            if ($last) {
                Set-Content -Path $containerPath -Value ([System.Convert]::FromBase64String((Get-Content -Path $containerPath -Encoding UTF8))) -Encoding Byte -Force
            } 
        } -argumentList $containerPath, $block, ($idx -eq 0), ($idx + $thisBlockSize -eq $content.Length)
        $idx += $thisBlockSize
    }
    Write-Host " Done."
}
Set-Alias -Name Copy-FileToAlpacaBcContainer -Value Copy-FileToCloudBcContainer
Export-ModuleMember -Function Copy-FileToCloudBcContainer -Alias Copy-FileToAlpacaBcContainer
