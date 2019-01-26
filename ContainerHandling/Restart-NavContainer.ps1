<# 
 .Synopsis
  Restart Nav container
 .Description
  Restart a Nav Container
 .Parameter containerName
  Name of the container you want to restart
 .Parameter renewBindings
  Include this switch if you want the container to renew bindings (f.ex. after renewing a certificate)
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.), -1 means wait forever, 0 means don't wait.
 .Example
  Restart-NavContainer -containerName test
 .Example
  Restart-NavContainer -containerName test -renewBindings
#>
function Restart-NavContainer {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [string]$containerName,
        [switch]$renewBindings,
        [int]$timeout = 1800
    )

    if ($renewBindings) {
        Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { 
            Set-Content -Path "c:\run\PublicDnsName.txt" -Value ""
        }
    }

    if (!(DockerDo -command restart -imageName $containerName)) {
        return
    }
    if ($timeout -ne 0) {
        Wait-NavContainerReady -containerName $containerName -timeout $timeout
    }
}
Export-ModuleMember -function Restart-NavContainer
