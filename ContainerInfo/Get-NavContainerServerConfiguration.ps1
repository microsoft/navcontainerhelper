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

    Write-Host "invoke"
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{ Param($ContainerName)
        Write-Host "inside invoke"
        $config = Get-NavServerInstance | Get-NAVServerConfiguration -AsXml
        $object = [ordered]@{ "ContainerName" = $ContainerName }
        if ($config) {
            $Config.configuration.appSettings.add | ForEach-Object{
                $object += @{ "$($_.Key)" = $_.Value }
            }
        }
        else {
            $object += @{ "ServerInstance" = "" }
        }
        $object | ConvertTo-Json -Depth 99 -compress
    } -argumentList $containerName | ConvertFrom-Json
    Write-Host "after invoke"
}
Set-Alias -Name Get-NavContainerServerConfiguration -Value Get-BcContainerServerConfiguration
Export-ModuleMember -Function Get-BcContainerServerConfiguration -Alias Get-NavContainerServerConfiguration
