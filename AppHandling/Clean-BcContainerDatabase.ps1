<# 
 .Synopsis
  Cleans the Database in a BC Container
 .Description
  This function will remove existing base app from the database in a container, leaving the container without app
  You will have to publish a new base app before Business Central is useful
 .Parameter containerName
  Name of the container in which you want to clean the database
 .Example
  Clean-BcContainerDatabase -containerName test
#>
function Clean-BcContainerDatabase {
    Param(
        [string] $containerName = "navserver"
    )

    $platform = Get-NavContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-NavContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform

    if ($platformversion.Major -lt 14) {
        throw "Container $containerName does not support the function Clean-NavContainerDatabase"
    }

    Add-Type -AssemblyName System.Net.Http

    $customconfig = Get-NavContainerServerConfiguration -ContainerName $containerName
    if ($customConfig.Multitenant -eq "True") {
        throw "This script doesn't support multitenancy"
    }

    Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param ( $customConfig, $platformversion )
        
        if (!(Test-Path "c:\run\my\license.flf")) {
            throw "Container must be started with a developer license in order to publish a new application"
        }

        Write-Host "Uninstalling apps"
        Get-NAVAppInfo $customConfig.ServerInstance | Where-Object { $_.Name -ne "System Application" } | Uninstall-NAVApp -DoNotSaveData -WarningAction Ignore -Force

        if ($customConfig.databaseInstance) {
            $databaseServerInstance = "$($customConfig.databaseServer)\$($customConfig.databaseInstance)"
        }
        else {
            $databaseServerInstance = $customConfig.databaseServer
        }

        if ($platformversion.Major -eq 14) {
            Write-Host "Removing C/AL Application Objects"
            Delete-NAVApplicationObject -DatabaseName $customConfig.databaseName -DatabaseServer $databaseServerInstance -Filter 'ID=1..1999999999' -SynchronizeSchemaChanges Force -Confirm:$false
        }
        else {
            # Run 3 times to remove dependent apps first
            Write-Host "Unpublishing apps"
            Get-NAVAppInfo $customConfig.ServerInstance | Where-Object { $_.Name -ne "System Application" } | Unpublish-NAVApp -WarningAction Ignore -ErrorAction Ignore
            Get-NAVAppInfo $customConfig.ServerInstance | Where-Object { $_.Name -ne "System Application" } | Unpublish-NAVApp -WarningAction Ignore -ErrorAction Ignore
            Get-NAVAppInfo $customConfig.ServerInstance | Where-Object { $_.Name -ne "System Application" } | Unpublish-NAVApp -WarningAction Ignore
        }

    } -argumentList $customConfig, $platformversion

}
Export-ModuleMember -Function Clean-BcContainerDatabase
