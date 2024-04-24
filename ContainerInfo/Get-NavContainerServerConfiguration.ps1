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

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{ Param($ContainerName)
        $config = Get-NAVServerConfiguration -serverinstance BC -AsXml
        $Object = [ordered]@{ "ContainerName" = $ContainerName }
        if ($config) {
            $Config.configuration.appSettings.add | ForEach-Object{
                $Object += @{ "$($_.Key)" = $_.Value }
            }
        }
        else {
            $Object += @{ "ServerInstance" = "" }
        }
        $object | ConvertTo-Json -Depth 99 -compress
    } -argumentList $containerName | ConvertFrom-Json
}
Set-Alias -Name Get-NavContainerServerConfiguration -Value Get-BcContainerServerConfiguration
Export-ModuleMember -Function Get-BcContainerServerConfiguration -Alias Get-NavContainerServerConfiguration
