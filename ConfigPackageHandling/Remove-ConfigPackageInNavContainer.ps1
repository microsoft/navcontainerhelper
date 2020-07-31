<# 
 .Synopsis
  Removes a configuration package from the application database in a NAV/BC Container
 .Description
  Create a session to a container and run Remove-NAVConfigurationPackageFile
 .Parameter containerName
  Name of the container in which you want to remove the configuration package from
 .Parameter configPackageCode
  The code of the configuration package you want to remove
 .Example
  Remove-ConfigPackageInBcContainer -containerName test2 -configPackageCode 'US.ENU.EXTENDED'
#>
function Remove-ConfigPackageInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $configPackageCode
    )

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($configPackageCode)
        Write-Host "Removing configuration package $configPackageCode"
        Remove-NAVConfigurationPackageFile -ServerInstance $ServerInstance -Code $configPackageCode -Force
    } -ArgumentList $configPackageCode
    Write-Host -ForegroundColor Green "Configuration package removed"
}
Set-Alias -Name Remove-ConfigPackageInNavContainer -Value Remove-ConfigPackageInBcContainer
Export-ModuleMember -Function Remove-ConfigPackageInBcContainer -Alias Remove-ConfigPackageInNavContainer
