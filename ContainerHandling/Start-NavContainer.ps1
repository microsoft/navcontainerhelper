<# 
 .Synopsis
  Start a NAV/BC Container
 .Description
  Start a Container
 .Parameter containerName
  Name of the container you want to start
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.), -1 means wait forever, 0 means don't wait.
 .Example
  Start-BcContainer -containerName test
#>
function Start-BcContainer {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [int] $timeout = 1800
    )

    if (!(DockerDo -command start -imageName $containerName)) {
        return
    }
    if ($timeout -ne 0) {
        Wait-BcContainerReady -containerName $containerName -timeout $timeout
    }
}
Set-Alias -Name Start-NavContainer -Value Start-BcContainer
Export-ModuleMember -Function Start-BcContainer -Alias Start-NavContainer
