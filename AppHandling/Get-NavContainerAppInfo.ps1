<# 
 .Synopsis
  Get Nav App Info from Nav container
 .Description
  Creates a session to the Nav container and runs the Nav CmdLet Get-NavAppInfo in the container
 .Parameter containerName
  Name of the container in which you want to enumerate apps (default navserver)
 .Example
  Get-NavContainerAppInfo -containerName test2
#>
function Get-NavContainerAppInfo {
    Param(
        [string]$containerName = "navserver"
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { 
        Get-NavAppInfo -ServerInstance NAV
    } 
}
Export-ModuleMember -Function Get-NavContainerAppInfo
