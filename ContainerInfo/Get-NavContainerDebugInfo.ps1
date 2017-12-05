<# 
 .Synopsis
  Extract metadata from a container to be able to give more specific information when reporting an issue on GitHub.
 .Description
  Returns the debugging info for a container when reporting an issue on GitHUb
 .Parameter containerName
  Name of the container for which you want to get the debugging info
 .Parameter IncludeEnvVars
  Name of the container for which you want to get the debugging info
 .Parameter IncludeDockerInfo
  Name of the container for which you want to get the debugging info
 .Parameter CopyToClipboard
  Name of the container for which you want to get the debugging info
 .Example 
  Get-NavContainerDebugInfo -containerName navserver
  Get basic debug information (only container labels will be included).
  .Example
  Get-NavContainerDebugInfo -containerName navserver -IncludeEnvVars -IncludeDockerInfo -IncludeDockerLogs
  Get complete debug information.
  .Example
  Get-NavContainerDebugInfo -containerName navserver -IncludeEnvVars -IncludeDockerInfo -CopyToClipboard
  Get complete debug information and copy it into the clipboard.
#>
function Get-NavContainerDebugInfo {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter()]
        [switch]$ExcludeEnvVars,
        [Parameter()]
        [switch]$ExcludeDockerInfo,
        [Parameter()]
        [switch]$ExcludeDockerLogs,
        [Parameter()]
        [switch]$IncludeSensitiveInformation,
        [Parameter()]
        [switch]$CopyToClipboard
    )

    Process {
        $debugInfo = @{}
        $inspect = docker inspect $containerName | ConvertFrom-Json

        if ($inspect.Config.Labels.psobject.Properties.Match('nav').Count -eq 0) {
            throw "Container $containerName is not a NAV container"
        }
        
        $debugInfo.Add('container.labels', $inspect.Config.Labels)
        
        if (!$ExcludeEnvVars) {
            $envs = $inspect.Config.Env.GetEnumerator() | where-object { $includeSensitiveInformation -or 
                                                                         (!($_.ToLowerInvariant().Contains("password") -or 
                                                                            $_.ToLowerInvariant().Startswith("navdvdurl=") -or 
                                                                            $_.ToLowerInvariant().Startswith("countryurl=") -or 
                                                                            $_.ToLowerInvariant().Startswith("licensefile=") -or 
                                                                            $_.ToLowerInvariant().Startswith("bakfile=") -or 
                                                                            $_.ToLowerInvariant().Startswith("folders=") -or 
                                                                            $_.ToLowerInvariant().Startswith("vsixurl=")))  }
            if ($envs) {
                $debugInfo.Add('container.env', $envs)
            }
        }

        if (!$ExcludeDockerInfo) {
            $dockerInfo = docker info
            if ($dockerInfo) {
                $debugInfo.Add('docker.info', $dockerInfo)
            }
        }

        if (!$ExcludeDockerLogs) {
            $logs = docker logs $containerName
            if ($logs) {
                $debugInfo.Add('container.logs', $logs)
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
