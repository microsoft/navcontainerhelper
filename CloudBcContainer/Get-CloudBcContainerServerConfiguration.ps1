<# 
 .Synopsis
  Retrieve the Server configuration from a Cloud Container as a powershell object
 .Description
  Returns all the settings of the middletier from a container.
 .PARAMETER authContext
  Authorization Context for Cloud BC Container Provider
 .PARAMETER containerId
  Container Id of the Cloud BC Container to copy file from
 .Example
  Get-CloudBcContainerServerConfiguration -authContext $authContext -containerId $containerId
#>
Function Get-CloudBcContainerServerConfiguration {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

    $ResultObjectArray = @()
    $config = Invoke-ScriptInCloudBcContainer -authContext $authContext -containerId $containerId -ScriptBlock{
        Get-NavServerInstance | Get-NAVServerConfiguration -AsXml
    }
    
    $Object = New-Object -TypeName PSObject -Property @{
        ContainerId = $ContainerId
    }

    if ($config) {
        $Config.configuration.appSettings.add | ForEach-Object{
            $Object | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }
    }
    else {
        $Object | Add-Member -MemberType NoteProperty -Name "ServerInstance" -Value ""
    }

    $ResultObjectArray += $Object
    
    Write-Output $ResultObjectArray
}
Set-Alias -Name Get-AlpacaBcContainerServerConfiguration -Value Get-CloudBcContainerServerConfiguration
Export-ModuleMember -Function Get-CloudBcContainerServerConfiguration -Alias Get-AlpacaBcContainerServerConfiguration
