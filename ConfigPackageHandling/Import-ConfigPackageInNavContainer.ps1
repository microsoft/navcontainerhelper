<# 
 .Synopsis
  Imports a configuration package into the application database
 .Description
  Create a session to a Nav container and run Import-NAVConfigurationPackageFile
 .Parameter containerName
  Name of the container in which you want to import the configuration package to
 .Parameter configPackageFile
  Path to the configuration package file you want to import
 .Example
  Import-ConfigPackageInNavContainer -containerName test2 -configPackage 'c:\temp\configPackage.rapidstart'
#>
function Import-ConfigPackageInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$configPackageFile
    )

    $containerConfigPackageFile = Get-NavContainerPath -containerName $containerName -path $configPackageFile -throw

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($configPackageFile)
        Write-Host "Importing configuration package from $configPackageFile (container path)"
        Import-NAVConfigurationPackageFile -ServerInstance NAV -Path $configPackageFile
    } -ArgumentList $containerConfigPackageFile
    Write-Host -ForegroundColor Green "Configuration package imported"
}
Export-ModuleMember -Function Import-ConfigPackageInNavContainer
