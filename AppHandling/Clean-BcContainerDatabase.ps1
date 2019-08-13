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
        [string] $containerName = "navserver",
        [switch] $saveData,
        [switch] $doNotUnpublish
    )

    $platform = Get-NavContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-NavContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform

    if ($platformversion.Major -lt 14) {
        throw "Container $containerName does not support the function Clean-NavContainerDatabase"
    }

    $myFolder = Join-Path $ExtensionsFolder "$containerName\my"

    if (!(Test-Path "$myFolder\license.flf")) {
        throw "Container must be started with a developer license in order to publish a new application"
    }

    $customconfig = Get-NavContainerServerConfiguration -ContainerName $containerName

    $installedApps = Get-NavContainerAppInfo -containerName $containerName -tenantSpecificProperties -sort DependenciesLast | Where-Object { $_.Name -ne "System Application" }
    $installedApps | % {
        $app = $_
        Invoke-ScriptInBCContainer -containerName test -scriptblock { Param($app, $SaveData)
            if ($app.IsInstalled) {
                Write-Host "Uninstalling $($app.Name)"
                $app | Uninstall-NavApp -Force -doNotSaveData:(!$SaveData)
            }
        } -argumentList $app, $SaveData
    }

    if ($platformversion.Major -eq 14) {
        Invoke-ScriptInNavContainer -containerName $containerName -scriptblock { Param ( $customConfig )
            
            if ($customConfig.databaseInstance) {
                $databaseServerInstance = "$($customConfig.databaseServer)\$($customConfig.databaseInstance)"
            }
            else {
                $databaseServerInstance = $customConfig.databaseServer
            }
    
            Write-Host "Removing C/AL Application Objects"
            Delete-NAVApplicationObject -DatabaseName $customConfig.databaseName -DatabaseServer $databaseServerInstance -Filter 'ID=1..1999999999' -SynchronizeSchemaChanges Force -Confirm:$false

        } -argumentList $customconfig
    }
    else {
        if (!$doNotUnpublish) {
            $installedApps | % {
                $app = $_
                Invoke-ScriptInBCContainer -containerName test -scriptblock { Param($app)
                    if ($app.IsPublished) {
                        Write-Host "Unpublishing $($app.Name)"
                        $app | UnPublish-NavApp
                    }
                } -argumentList $app
            }
        }
    }
}
Export-ModuleMember -Function Clean-BcContainerDatabase
