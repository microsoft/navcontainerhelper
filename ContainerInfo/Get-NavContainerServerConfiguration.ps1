<# 
 .Synopsis
  Retrieve the Server configuration from a NAV/BC Container as a powershell object
 .Description
  Returns all the settings of the middletier from a container.
 .Parameter containerName
  Name of the container for which you want to get the server configuration
 .Example
  Get-BcContainerServerConfiguration -ContainerName "MyContainer"
#>
Function Get-BcContainerServerConfiguration {
    Param (
        [String] $ContainerName = $bcContainerHelperConfig.defaultContainerName
    )

    $ResultObjectArray = @()
    $config = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{
        Get-NavServerInstance | Get-NAVServerConfiguration -AsXml
    }
    
    $Object = New-Object -TypeName PSObject -Property @{
        ContainerName = $ContainerName
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
Set-Alias -Name Get-NavContainerServerConfiguration -Value Get-BcContainerServerConfiguration
Export-ModuleMember -Function Get-BcContainerServerConfiguration -Alias Get-NavContainerServerConfiguration
