<# 
 .Synopsis
  Cleans the Database in a BC Container
 .Description
  This function will remove existing base app from the database in a container, leaving the container without app
  You will have to publish a new base app before Business Central is useful
 .Parameter containerName
  Name of the container in which you want to clean the database
 .Parameter saveData
  Include the saveData switch if you want to save data while uninstalling apps
 .Parameter onlySaveBaseAppData
  Include the onlySaveBaseAppData switch if you want to only save data in the base application and not in other apps
 .Parameter doNotUnpublish
  Include the doNotUnpublish switch if you do not want to unpublish apps (only 15.x containers or later)
 .Parameter useNewDatabase
  Add this switch if you want to create a new and empty database in the container
  This switch (or useCleanDatabase) is needed when turning a C/AL container into an AL Container.
 .Parameter companyName
  CompanyName when using -useNewDatabase. Default is My Company.
 .Parameter credential
  Credentials of the container super user if using NavUserPassword authentication
 .Example
  Clean-BcContainerDatabase -containerName test
#>
function Clean-BcContainerDatabase {
    Param (
        [string] $containerName = "navserver",
        [switch] $saveData,
        [Switch] $onlySaveBaseAppData,
        [switch] $doNotUnpublish,
        [switch] $useNewDatabase,
        [string] $companyName = "My Company",
        [PSCredential] $credential
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
        throw "Container must be started with a developer license to perform this operation"
    }

    $customconfig = Get-NavContainerServerConfiguration -ContainerName $containerName

    if ($useNewDatabase) {
        if ($saveData) {
            throw "Cannot use SaveData with useNewDatabase."
        }
        if ($doNotUnpublish) {
            throw "Cannot use doNotUnpublish with useNewDatabase."
        }
        if ($customconfig.ClientServicesCredentialType -ne "Windows" -and !($credential)) {
            throw "You need to specify credentials if using useNewDatabase and authentication is not Windows"
        }

        if ($platformversion.Major -lt 15) {
            $SystemSymbolsFile = Join-Path $ExtensionsFolder "$containerName\system.app"
            $systemSymbols = Get-NavContainerAppInfo -containerName $containerName -symbolsOnly | Where-Object { $_.Name -eq "System" }
            Get-NavContainerApp -containerName $containerName -appName $SystemSymbols.Name -publisher $SystemSymbols.Publisher -appVersion $SystemSymbols.Version -appFile $SystemSymbolsFile -credential $credential
            $SystemApplicationFile = ""
        }
        else {
            $SystemSymbolsFile = ":" + (Invoke-ScriptInBCContainer -containerName $containerName -scriptblock {
                (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\AL Development Environment\System.app").FullName
            })
            $SystemApplicationFile = ":C:\Applications\System Application\Source\Microsoft_System Application.app"
        }

        Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($platformVersion, $databaseName, $databaseServer, $databaseInstance)
        
            Write-Host "Stopping ServiceTier in order to replace database"
            Set-NavServerInstance -ServerInstance $ServerInstance -stop
        
            if ($platformVersion.Major -ge 15) {
                $dbproperties = Invoke-Sqlcmd -Query "SELECT [applicationversion],[applicationfamily] FROM [$databaseName].[dbo].[`$ndo`$dbproperty]"
            }
        
            Remove-NavDatabase -databasename $databaseName -databaseserver $databaseServer -databaseInstance $databaseInstance
            $databaseServerInstance = $databaseServer
            if ($databaseInstance) {
                $databaseServerInstance += "\$databaseInstance"
            }
            $CollationParam = @{}
            if (Test-Path "c:\run\Collation.txt") {
                $Collation = Get-Content "c:\run\Collation.txt"
                $CollationParam = @{ "Collation" = $collation }
                Write-Host "Creating new database $databaseName on $databaseServerInstance with Collation $Collation"
            }
            else {
                Write-Host "Creating new database $databaseName on $databaseServerInstance with default Collation"
            }

            if ($platformVersion.Major -ge 15) {
                New-NAVApplicationDatabase -DatabaseServer $databaseServerInstance -DatabaseName $databaseName @CollationParam | Out-Null
                Invoke-Sqlcmd -Query "UPDATE [$databaseName].[dbo].[`$ndo`$dbproperty] SET [applicationfamily] = '$($dbproperties.applicationfamily)', [applicationversion] = '$($dbproperties.applicationversion)'"
            }
            else {
                Create-NAVDatabase -databasename $databaseName -databaseserver $databaseServerInstance @CollationParam | Out-Null
            }
            
            Write-Host "Starting Service Tier"
            Set-NavServerInstance -ServerInstance $ServerInstance -start
            
            Write-Host "Synchronizing"
            Sync-NavTenant -ServerInstance $ServerInstance -Force
        
        } -argumentList $platformVersion, $customconfig.DatabaseName, $customconfig.DatabaseServer, $customconfig.DatabaseInstance
        
        Import-NavContainerLicense -containerName $containerName -licenseFile "$myFolder\license.flf"
        
        if ($customconfig.ClientServicesCredentialType -eq "Windows") {
            Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($username)
                New-NavServerUser -ServerInstance $ServerInstance -WindowsAccount $username
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -WindowsAccount $username -PermissionSetId SUPER
            } -argumentList $env:USERNAME
        }
        else {
            New-NavContainerNavUser -containerName $containerName -Credential $credential -PermissionSetId SUPER -ChangePasswordAtNextLogOn:$false
        }
        
        Publish-NavContainerApp -containerName $containerName -appFile $SystemSymbolsFile -packageType SymbolsOnly -skipVerification

        New-CompanyInBCContainer -containerName $containerName -companyName $companyName
        
        if ($SystemApplicationFile) {
            Publish-NavContainerApp -containerName $containerName -appFile $SystemApplicationFile -skipVerification -install -sync
        }

    }
    else {
    
        $installedApps = Get-NavContainerAppInfo -containerName $containerName -tenantSpecificProperties -sort DependenciesLast | Where-Object { $_.Name -ne "System Application" }
        $installedApps | % {
            $app = $_
            Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($app, $SaveData, $onlySaveBaseAppData)
                if ($app.IsInstalled) {
                    Write-Host "Uninstalling $($app.Name)"
                    $app | Uninstall-NavApp -Force -doNotSaveData:(!$SaveData -or ($Name -ne "BaseApp" -and $Name -ne "Base Application" -and $onlySaveBaseAppData))
                }
            } -argumentList $app, $SaveData, $onlySaveBaseAppData
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
                    Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($app)
                        if ($app.IsPublished) {
                            Write-Host "Unpublishing $($app.Name)"
                            $app | UnPublish-NavApp
                        }
                    } -argumentList $app
                }
            }
        }
    }
}
Export-ModuleMember -Function Clean-BcContainerDatabase
