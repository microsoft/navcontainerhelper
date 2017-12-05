<# 
 .Synopsis
  Extract metadata from a container to be able to give more specific information when reporting an issue on GitHub.
 .Description
  Returns the generic Tag version referring to a release from http://www.github.com/microsoft/nav-docker
 .Parameter containerOrImageName
  Name of the container or container image for which you want to get the debugging info.
 .Example 
  Get-NavContainerDebugInfo -containerName navserver
  Get basic debug information (only container labels will be included).
  .Example
  Get-NavContainerDebugInfo -containerName navserver -IncludeEnvVars -IncludeDockeInfo
  Get complete debug information.
  This may contain some sensitive information (especially when using -IncludeEnvVars switch).
  .Example
  Get-NavContainerDebugInfo -containerName navserver -IncludeEnvVars -IncludeDockeInfo -CopyToClipboard
  Get complete debug information and copy it into the clipboard.
  This may contain some sensitive information (especially when using -IncludeEnvVars switch).
#>
function Get-NavContainerDebugInfo {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter()]
        [switch]$IncludeEnvVars,
        [Parameter()]
        [switch]$IncludeDockeInfo,
        [Parameter()]
        [switch]$CopyToClipboard
    )

    Process {
        $debugInfo = @{}
        $inspect = docker inspect $containerName | ConvertFrom-Json
        
        $debugInfo.Add('container.labels', $inspect.Config.Labels)
        
        if ($IncludeEnvVars) {
            # Maybe some obfuscation on passwords etc. would be handy here.
            $envs = $inspect.Config.Env
            if ($envs) {
                $debugInfo.Add('container.env', $envs)
            }
        }

        if ($IncludeDockeInfo) {
            $dockeInfo = docker info
            if ($dockeInfo) {
                $debugInfo.Add('docker.info', $dockeInfo)
            }
        }

        $debugInfoJson = ConvertTo-Json $debugInfo

        if ($CopyToClipboard) {
            $debugInfoJson | Set-Clipboard
        }
        
        return $debugInfoJson
    }
}
Export-ModuleMember -function Get-NavContainerDebugInfo
