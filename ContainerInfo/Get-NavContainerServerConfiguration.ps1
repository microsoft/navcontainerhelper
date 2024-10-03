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

    Write-Host "Get Server Configuration for container $ContainerName"
    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock{ Param($ContainerName)
        Write-Host "get it"
        $config = Get-NavServerInstance | Get-NAVServerConfiguration -AsXml
        Write-Host "make obj"
        $object = [ordered]@{ "ContainerName" = $ContainerName }
        if ($config) {
            $Config.configuration.appSettings.add | ForEach-Object{
                Write-Host "$($_.Key) = $($_.Value)"
                $object += @{ "$($_.Key)" = $_.Value }
            }
        }
        else {
            $object += @{ "ServerInstance" = "" }
        }
        Write-Host "return it"
        $object | ConvertTo-Json -Depth 99 -compress
    } -argumentList $containerName | ConvertFrom-Json
}
Set-Alias -Name Get-NavContainerServerConfiguration -Value Get-BcContainerServerConfiguration
Export-ModuleMember -Function Get-BcContainerServerConfiguration -Alias Get-NavContainerServerConfiguration
