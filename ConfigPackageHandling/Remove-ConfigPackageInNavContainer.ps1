<# 
 .Synopsis
  Removes a configuration package from the application database
 .Description
  Create a session to a Nav container and run Remove-NAVConfigurationPackageFile
 .Parameter containerName
  Name of the container in which you want to remove the configuration package from
 .Parameter configPackageCode
  The code of the configuration package you want to remove
 .Example
  Remove-ConfigPackageInNavContainer -containerName test2 -configPackageCode 'US.ENU.EXTENDED'
#>
function Remove-ConfigPackageInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$configPackageCode
    )

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($configPackageCode)
        Write-Host "Removing configuration package $configPackageCode"
        Remove-NAVConfigurationPackageFile -ServerInstance NAV -Code $configPackageCode -Force
    } -ArgumentList $configPackageCode
    Write-Host -ForegroundColor Green "Configuration package removed"
}
Export-ModuleMember -Function Remove-ConfigPackageInNavContainer
