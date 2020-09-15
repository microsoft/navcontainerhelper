<# 
 .Synopsis
  Restart a NAV/BC Container
 .Description
  Restart a Container
 .Parameter containerName
  Name of the container you want to restart
 .Parameter renewBindings
  Include this switch if you want the container to renew bindings (f.ex. after renewing a certificate)
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.), -1 means wait forever, 0 means don't wait.
 .Example
  Restart-BcContainer -containerName test
 .Example
  Restart-BcContainer -containerName test -renewBindings
#>
function Restart-BcContainer {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [switch] $renewBindings,
        [int] $timeout = 1800
    )

    if ($renewBindings) {
        Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { 
            Set-Content -Path "c:\run\PublicDnsName.txt" -Value ""
        }
    }

    if (!(DockerDo -command restart -imageName $containerName)) {
        return
    }
    if ($timeout -ne 0) {
        Wait-BcContainerReady -containerName $containerName -timeout $timeout
    }
}
Set-Alias -Name Restart-NavContainer -Value Restart-BcContainer
Export-ModuleMember -Function Restart-BcContainer -Alias Restart-NavContainer
