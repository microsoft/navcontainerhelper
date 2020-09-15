<# 
 .Synopsis
  Imports a configuration package into the application database in a NAV/BC Container
 .Description
  Create a session to a container and run Import-NAVConfigurationPackageFile
 .Parameter containerName
  Name of the container in which you want to import the configuration package to
 .Parameter configPackageFile
  Path to the configuration package file you want to import
 .Example
  Import-ConfigPackageInBcContainer -containerName test2 -configPackage 'c:\temp\configPackage.rapidstart'
#>
function Import-ConfigPackageInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $configPackageFile
    )

    $containerConfigPackageFile = Get-BcContainerPath -containerName $containerName -path $configPackageFile -throw

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($configPackageFile)
        Write-Host "Importing configuration package from $configPackageFile (container path)"
        Import-NAVConfigurationPackageFile -ServerInstance $ServerInstance -Path $configPackageFile
    } -ArgumentList $containerConfigPackageFile
    Write-Host -ForegroundColor Green "Configuration package imported"
}
Set-Alias -Name Import-ConfigPackageInNavContainer -Value Import-ConfigPackageInBcContainer
Export-ModuleMember -Function Import-ConfigPackageInBcContainer -Alias Import-ConfigPackageInNavContainer
